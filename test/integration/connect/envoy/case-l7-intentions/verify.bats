#!/usr/bin/env bats

load helpers

@test "s1 proxy admin is up on :19000" {
  retry_default curl -f -s localhost:19000/stats -o /dev/null
}

@test "s2 proxy admin is up on :19001" {
  retry_default curl -f -s localhost:19001/stats -o /dev/null
}

@test "s1 proxy listener should be up and have right cert" {
  assert_proxy_presents_cert_uri localhost:21000 s1
}

@test "s2 proxy listener should be up and have right cert" {
  assert_proxy_presents_cert_uri localhost:21001 s2
}

@test "s2 proxies should be healthy" {
  assert_service_has_healthy_instances s2 1
}

@test "s1 upstream should have healthy endpoints for s2" {
  assert_upstream_has_endpoints_in_status 127.0.0.1:19000 s2.default.primary HEALTHY 1
}

@test "s2 should have http rbac rules loaded from xDS" {
  retry_default assert_envoy_http_rbac_policy_count localhost:19001 1
}

# these all use the same context: "s1 upstream should be able to connect to s2 via upstream s2"

@test "test exact path" {
  retry_default must_pass_http_request GET localhost:5000/exact
  retry_default must_fail_http_request 403 GET localhost:5000/exact-nope
}

@test "test prefix path" {
  retry_default must_pass_http_request GET localhost:5000/prefix
  retry_default must_fail_http_request 403 GET localhost:5000/nope-prefix
}

@test "test regex path" {
  retry_default must_pass_http_request GET localhost:5000/regex
  retry_default must_fail_http_request 403 GET localhost:5000/reggex
}

@test "test present header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-present x-test-debug:anything
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-present x-test-debug:
}

@test "test exact header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-exact x-test-debug:exact
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-exact x-test-debug:exact-nope
}

@test "test prefix header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-prefix x-test-debug:prefix
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-prefix x-test-debug:nope-prefix
}

@test "test suffix header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-suffix x-test-debug:suffix
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-suffix x-test-debug:suffix-nope
}

@test "test contains header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-contains x-test-debug:contains
  retry_default must_pass_http_request GET localhost:5000/hdr-contains x-test-debug:ccontainss
  retry_default must_pass_http_request GET localhost:5000/hdr-contains x-test-debug:still-contains-value
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-contains x-test-debug:conntains
}

@test "test regex header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-regex x-test-debug:regex
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-regex x-test-debug:reggex
}

@test "test exact ignore case header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-exact-ignore-case x-test-debug:foo.bar.com
  retry_default must_pass_http_request GET localhost:5000/hdr-exact-ignore-case x-test-debug:foo.BAR.com
  retry_default must_pass_http_request GET localhost:5000/hdr-exact-ignore-case x-test-debug:fOo.bAr.coM
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-exact-ignore-case x-test-debug:fOo.bAr.coM.nope
}

@test "test prefix ignore case header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-prefix-ignore-case x-test-debug:foo.bar.com
  retry_default must_pass_http_request GET localhost:5000/hdr-prefix-ignore-case x-test-debug:foo.BAR.com
  retry_default must_pass_http_request GET localhost:5000/hdr-prefix-ignore-case x-test-debug:fOo.bAr.coM
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-prefix-ignore-case x-test-debug:nope.fOo.bAr.coM
}

@test "test suffix ignore case header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-suffix-ignore-case x-test-debug:foo.bar.com
  retry_default must_pass_http_request GET localhost:5000/hdr-suffix-ignore-case x-test-debug:foo.BAR.com
  retry_default must_pass_http_request GET localhost:5000/hdr-suffix-ignore-case x-test-debug:fOo.bAr.coM
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-suffix-ignore-case x-test-debug:fOo.bAr.coM.nope
}

@test "test contains ignore case header" {
  retry_default must_pass_http_request GET localhost:5000/hdr-contains-ignore-case x-test-debug:cOntAins
  retry_default must_pass_http_request GET localhost:5000/hdr-contains-ignore-case x-test-debug:CconTainsS
  retry_default must_pass_http_request GET localhost:5000/hdr-contains-ignore-case x-test-debug:still-cOntAins-value
  retry_default must_fail_http_request 403 GET localhost:5000/hdr-contains-ignore-case x-test-debug:cOnntAins
}

@test "test method match" {
  retry_default must_pass_http_request GET localhost:5000/method-match
  retry_default must_pass_http_request PUT localhost:5000/method-match
  retry_default must_fail_http_request 403 POST localhost:5000/method-match
  retry_default must_fail_http_request 403 HEAD localhost:5000/method-match
}

# @test "s1 upstream should NOT be able to connect to s2" {
#   run retry_default must_fail_tcp_connection localhost:5000

#   echo "OUTPUT $output"

#   [ "$status" == "0" ]
# }
