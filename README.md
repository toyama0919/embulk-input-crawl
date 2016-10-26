# Crawl input plugin for Embulk

Crawl by Anemone input plugin for Embulk.

## Overview

* **Plugin type**: input
* **Resume supported**: yes
* **Cleanup supported**: yes
* **Guess supported**: no

## Configuration

- **payloads**: payloads (array, default: `null`)
- **reject_url_regexp**: reject_url_regexp (string, default: `null`)
- **url_key_of_payload**: url_key_of_payload (string, default: `url`)
- **user_agent**: user_agent (string, default: `null`)
- **obey_robots_txt**: don't obey the robots exclusion protocol (bool, default: `false`)
- **skip_query_strings**: skip_query_strings (bool, default: `false`)
- **add_payload_to_record**: add_payload_to_record (bool, default: `false`)
- **accept_cookies**: accept_cookies (bool, default: `false`)
- **delay**: delay (integer, default: `null`)
- **depth_limit**: by default, don't limit the depth of the crawl (integer, default: `null`)
- **read_timeout**: HTTP read timeout in seconds (integer, default: `null`)
- **redirect_limit**: number of times HTTP redirects will be followed (integer, default: `null`)
- **cookies**: Hash of cookie name => value to send with HTTP requests (hash, default: `null`)

## Example

```yaml
in:
  type: crawl
  payloads:
    - {"id":3,"url":"http://www-stg1.jp"}
    - {"id":4,"url":"http://www-stg2.jp"}
  add_payload: true
  user_agent: 'Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko'
  obey_robots_txt: true
  skip_query_strings: false
  add_payload_to_record: true
  accept_cookies: true
  url_key_of_payload: url
  depth_limit: 5
  read_timeout: 10
  delay: 4
  redirect_limit: 3
  cookies: { UUID: hoge }
  crawl_url_regexp: '\/detail\/'
  reject_url_regexp: '\.(jpg|JPG|png|PNG|jpeg|JPEG|gif|GIF|jpm|zip|ZIP|doc|docx|xls|xlsx|bmp|BMP|pdf|PDF|exe|EXE|dll|DLL)(\?|$)'

```

## Output Schema

```
  Column.new(0, "url", :string),
  Column.new(1, "title", :string),
  Column.new(2, "body", :string),
  Column.new(3, "time", :timestamp),
  Column.new(4, "code", :long),
  Column.new(5, "response_time", :long),
  Column.new(6, "payload", :json) if task['add_payload_to_record']

```


## Build

```
$ rake
```
