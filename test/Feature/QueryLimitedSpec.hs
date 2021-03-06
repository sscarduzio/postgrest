module Feature.QueryLimitedSpec where

import Test.Hspec hiding (pendingWith)
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON
import Network.HTTP.Types
import Network.Wai.Test (SResponse(simpleHeaders, simpleStatus))

import Hasql as H
import Hasql.Postgres as P

import SpecHelper
import PostgREST.Types (DbStructure(..))

spec :: DbStructure -> H.Pool P.Postgres -> Spec
spec struct pool =
  beforeAll resetDb
   . around (withApp (cfgLimitRows 3) struct pool) $
  describe "Requesting many items with server limits enabled" $ do
    it "restricts results" $
      get "/items"
        `shouldRespondWith` ResponseMatcher {
          matchBody    = Just [json| [{"id":1},{"id":2},{"id":3}] |]
        , matchStatus  = 206
        , matchHeaders = ["Content-Range" <:> "0-2/15"]
        }

    it "respects additional client limiting" $ do
      r <- request methodGet  "/items"
                   (rangeHdrs $ ByteRangeFromTo 0 1) ""
      liftIO $ do
        simpleHeaders r `shouldSatisfy`
          matchHeader "Content-Range" "0-1/15"
        simpleStatus r `shouldBe` partialContent206
