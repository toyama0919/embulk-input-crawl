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
- **obey_robots_txt**: obey_robots_txt (bool, default: `false`)
- **skip_query_strings**: skip_query_strings (bool, default: `false`)
- **add_payload_to_record**: add_payload_to_record (bool, default: `false`)
- **accept_cookies**: accept_cookies (bool, default: `false`)
- **delay**: delay (integer, default: `null`)
- **depth_limit**: depth_limit (integer, default: `null`)
- **read_timeout**: read_timeout (integer, default: `null`)
- **redirect_limit**: redirect_limit (integer, default: `null`)
- **cookies**: cookies (hash, default: `null`)

## Example

```yaml
in:
  type: crawl
  payloads:
    - {"id":3,"url":"http://hoge.jp"}
  add_payload: true
  delay: 4
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
