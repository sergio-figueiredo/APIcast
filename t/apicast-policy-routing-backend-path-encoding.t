use lib 't';
use Test::APIcast::Blackbox 'no_plan';

run_tests();

__DATA__

=== TEST 1: backend with a path keeps percent-encoded characters in the upstream request path
The routing rule mirrors the one 3scale (porta) generates for a Backend used
with a public path: the private URL has a path and replace_path removes the
public path from the decoded uri. Characters such as "|" must reach the
upstream percent-encoded; sent raw, strict HTTP servers reject the request
line with 400.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.routing",
            "configuration": {
              "rules": [
                {
                  "url": "http://test:$TEST_NGINX_SERVER_PORT/REST/svc",
                  "replace_path": "{{uri | remove_first: '/REST/svc'}}",
                  "condition": {
                    "operations": [
                      { "match": "path", "op": "matches", "value": "^(/REST/svc/.*|/REST/svc/?)" }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  ]
}
--- upstream
  location ~ / {
     content_by_lua_block {
       ngx.say(ngx.var.request_uri)
     }
  }
--- request eval
["GET /REST/svc/cards/id%7C42", "GET /REST/svc/a%22b", "GET /REST/svc/a%5Eb", "GET /REST/svc/a%7Bb%7D", "GET /REST/svc/a%20b"]
--- response_body eval
["/REST/svc/cards/id%7C42\n", "/REST/svc/a%22b\n", "/REST/svc/a%5Eb\n", "/REST/svc/a%7Bb%7D\n", "/REST/svc/a%20b\n"]
--- error_code eval
[200, 200, 200, 200, 200]
--- no_error_log
[error]


=== TEST 2: backend with a path keeps "%3F" and "%2F" in the upstream request path
A percent-encoded "?" or "/" in a path segment is data, not a delimiter.
Decoded, "?" truncates the path and the rest of the segment is lost; "/"
adds a path segment that the client never sent.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.routing",
            "configuration": {
              "rules": [
                {
                  "url": "http://test:$TEST_NGINX_SERVER_PORT/REST/svc",
                  "replace_path": "{{uri | remove_first: '/REST/svc'}}",
                  "condition": {
                    "operations": [
                      { "match": "path", "op": "matches", "value": "^(/REST/svc/.*|/REST/svc/?)" }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  ]
}
--- upstream
  location ~ / {
     content_by_lua_block {
       ngx.say(ngx.var.request_uri)
     }
  }
--- request eval
["GET /REST/svc/files/a%3Fb", "GET /REST/svc/files/a%3Fb?x=1", "GET /REST/svc/files/a%2Fb"]
--- response_body eval
["/REST/svc/files/a%3Fb
", "/REST/svc/files/a%3Fb?x=1
", "/REST/svc/files/a%2Fb
"]
--- error_code eval
[200, 200, 200]
--- no_error_log
[error]
