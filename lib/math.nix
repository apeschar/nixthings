let
  pow = base: exponent:
    if exponent > 0
    then let
      and1 = x: (x / 2) * 2 != x;
      x = pow base (exponent / 2);
    in
      assert and1 0 == false;
      assert and1 1 == true;
      assert and1 2 == false;
      assert and1 3 == true;
        x
        * x
        * (
          if and1 exponent
          then base
          else 1
        )
    else if exponent == 0
    then 1
    else throw "undefined";
in
  assert pow 0 1000 == 0;
  assert pow 1000 0 == 1;
  assert pow 2 30 == 1073741824;
  assert pow 3 3 == 27;
  assert pow (-5) 3 == -125; {
    inherit pow;
  }
