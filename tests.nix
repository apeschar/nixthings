{
  math,
  ipgen,
  runTests,
}:
runTests {
  testPow = {
    expr = math.pow 2 8;
    expected = 256;
  };
  testIpgen64 = let
    subnet = "2a01:4f9:3051:429c::/64";
  in {
    expr = ipgen.ip6 subnet "hello";
    expected = "2a01:4f9:3051:429c:26e8:3b2a:c5b9:e29e";
  };
  testIpgen32 = let
    subnet = "2a01:4f9:3051:429c::/32";
  in {
    expr = ipgen.ip6 subnet "hello";
    expected = "2a01:4f9:5fb0:a30e:26e8:3b2a:c5b9:e29e";
  };
  testIpgenIp6ll = {
    expr = ipgen.ip4ll "hello";
    expected = "169.254.77.186";
  };
  testIpgenIp6llReserved0 = {
    expr = ipgen.ip4ll "257";
    expected = "169.254.217.68";
  };
  testIpgenIp6llReserved254 = {
    expr = ipgen.ip4ll "95";
    expected = "169.254.73.157";
  };
  testIpgenPrivateIp4 = {
    expr = ipgen.privateIp4 0 "hello";
    expected = "10.242.77.186";
  };
  testIpgenPrivateIp4' = {
    expr = ipgen.privateIp4 1 "hello";
    expected = "10.242.77.187";
  };
}
