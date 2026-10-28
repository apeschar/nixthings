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
