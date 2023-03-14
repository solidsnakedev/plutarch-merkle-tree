module Plutarch.MerkleTree (validator, PHash (PHash), PMerkleTree (..), phash, pmember) where

import Plutarch.Api.V2 (
  PValidator,
 )
import Plutarch.Prelude

-- import Plutarch.Bool (PPartialOrd)

newtype PHash (s :: S) = PHash (Term s PByteString)
  deriving stock (Generic)
  deriving anyclass (PlutusType, PEq)

instance DerivePlutusType PHash where type DPTStrat _ = PlutusTypeNewtype

instance Semigroup (Term s PHash) where
  x' <> y' =
    phoistAcyclic
      ( plam $ \x y -> pmatch x $ \(PHash h0) ->
          pmatch y $ \(PHash h1) ->
            pcon $ PHash (h0 <> h1)
      )
      # x'
      # y'

instance Monoid (Term s PHash) where
  mempty = pcon $ PHash mempty

data PMerkleTree (s :: S)
  = PMerkleEmpty
  | PMerkleNode (Term s PHash) (Term s PMerkleTree) (Term s PMerkleTree)
  | PMerkleLeaf (Term s PHash) (Term s PByteString)
  deriving stock (Generic)
  deriving anyclass (PlutusType)

instance DerivePlutusType PMerkleTree where type DPTStrat _ = PlutusTypeScott

instance PEq PMerkleTree where
  l' #== r' =
    phoistAcyclic
      ( plam $ \l r ->
          pmatch l $ \case
            PMerkleEmpty -> pmatch r $ \case
              PMerkleEmpty -> pcon PTrue
              _ -> pcon PFalse
            PMerkleNode h0 _ _ -> pmatch r $ \case
              PMerkleNode h1 _ _ -> h0 #== h1
              _ -> pcon PFalse
            PMerkleLeaf h0 _ -> pmatch r $ \case
              PMerkleLeaf h1 _ -> h0 #== h1
              _ -> pcon PFalse
      )
      # l'
      # r'

type PProof = PList (PEither PHash PHash)

-- mkProof :: forall (s :: S). Term s (PByteString :--> PMerkleTree :--> PMaybe PProof)
-- mkProof = undefined

pmember :: forall (s :: S). Term s (PByteString :--> PHash :--> PProof :--> PBool)
pmember = phoistAcyclic $
  plam $ \bs root ->
    let go = pfix #$ plam $ \self root' proof ->
          pmatch proof $ \case
            PSNil -> root' #== root
            PSCons x xs -> pmatch x $ \case
              PLeft l -> self # (l <> root') # xs
              PRight r -> self # (root' <> r) # xs
     in go # (phash # bs)

-- member :: BuiltinByteString -> Hash -> Proof -> Bool
-- member e root = go (hash e)
--  where
--   go root' = \case
--     [] -> root' == root
--     Left l : q -> go (combineHash l root') q
--     Right r : q -> go (combineHash root' r) q

-- test :: Integer -> Maybe Integer -> Bool
-- test _i = go (_i)
--   where
--     go (_i') = \case
--       Just _ -> True
--       Nothing -> False

phash :: forall (s :: S). Term s (PByteString :--> PHash)
phash = phoistAcyclic $ plam $ \bs ->
  pcon $ PHash (psha2_256 # bs)

validator :: ClosedTerm PValidator
validator = plam $ \_ _ _ -> popaque $ pconstant True
