{-# LANGUAGE AllowAmbiguousTypes   #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}


module Interpreters where
import           Control.Exception (ArithException (..), SomeException, throwIO)
import           Domain
import           Eff
import           Eff.Exc
import           Eff.Region
import           Eff.SafeIO        (SIO, safeIO)
import           Language.Bar
import           Language.CashDesk
import           Language.Kitchen

data Oven = Oven deriving Eq

instance SafeForRegion Oven '[SIO, Exc SomeException]

type instance ResourceCtor Oven = ()


ovenRegion :: forall r a. ( SafeForRegion Oven r, Member SIO r, Member (Exc SomeException) r) => Region Oven r a -> Eff r a
ovenRegion = handleRegionRelay turnOn turnOff catchSafeIOExcs
  where
    turnOn _ = do
      safeIO $ putStrLn "heating up oven"
      return (Oven)
    turnOff _ = do
      safeIO $ putStrLn "turned oven off"


bakePizza :: forall r s. ( s ~ Ancestor 0 r, Member (RegionEff Oven s) r) => Eff r ()
bakePizza = acquire @Oven () >> return ()


runKitchen :: (SafeForRegion Oven r, Member SIO r, Member (Exc SomeException) r) => Eff (Kitchen ': r) a -> Eff r a
runKitchen = handleRelay pure (\k q -> interpret k >>= q) where
    interpret :: (SafeForRegion Oven r, Member SIO r, Member (Exc SomeException) r)  => Kitchen x -> Eff r x
    interpret (OrderPizza pizza) = (do
          safeIO $ print pizza
          ovenRegion $ do
            bakePizza
            safeIO $ putStrLn $ "baking " ++ (show pizza)
            _ <- safeIO $ throwIO Overflow
            safeIO $ putStrLn "this doesn't get run"
          return 12)

    interpret (Complain complaint) = safeIO (print complaint)

runBar :: (Member SIO r, Member (Exc SomeException) r) => Eff (Bar ': r) a -> Eff r a
runBar = handleRelay pure (\k q -> interpret k >>= q) where
    interpret :: (Member SIO r, Member (Exc SomeException) r)  => Bar x -> Eff r x
    interpret (ServeWine) = safeIO $ do
                putStrLn "Serving some wine"
                return "Merlot"
    interpret (ServeAppetizers time) = safeIO $ putStrLn $ "Appetizers for waiting time: " ++ show time


runCashDesk :: (Member SIO r, Member (Exc SomeException) r) => Eff (CashDesk ': r) a -> Eff r a
runCashDesk = handleRelay pure (\k q -> interpret k >>= q) where
    interpret :: (Member SIO r, Member (Exc SomeException) r)  => CashDesk x -> Eff r x
    interpret (MakeBill) = safeIO $ do
        putStrLn "Printing bill"
        return 421
    interpret (PayTheBill amt) = safeIO $ do
      putStrLn $ "Paid " ++ show amt
      return Nothing
