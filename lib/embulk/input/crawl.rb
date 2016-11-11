require 'anemone'

module Embulk
  module Input

    # Anemone default setting
    # DEFAULT_OPTS = {
    #   # run 4 Tentacle threads to fetch pages
    #   :threads => 4,
    #   # disable verbose output
    #   :verbose => false,
    #   # don't throw away the page response body after scanning it for links
    #   :discard_page_bodies => false,
    #   # identify self as Anemone/VERSION
    #   :user_agent => "Anemone/#{Anemone::VERSION}",
    #   # no delay between requests
    #   :delay => 0,
    #   # don't obey the robots exclusion protocol
    #   :obey_robots_txt => false,
    #   # by default, don't limit the depth of the crawl
    #   :depth_limit => false,
    #   # number of times HTTP redirects will be followed
    #   :redirect_limit => 5,
    #   # storage engine defaults to Hash in +process_options+ if none specified
    #   :storage => nil,
    #   # Hash of cookie name => value to send with HTTP requests
    #   :cookies => nil,
    #   # accept cookies from the server and send them back?
    #   :accept_cookies => false,
    #   # skip any link with a query string? e.g. http://foo.com/?u=user
    #   :skip_query_strings => false,
    #   # proxy server hostname 
    #   :proxy_host => nil,
    #   # proxy server port number
    #   :proxy_port => false,
    #   # HTTP read timeout in seconds
    #   :read_timeout => nil
    # }

    class Crawl < InputPlugin
      Plugin.register_input("crawl", self)

      def self.transaction(config, &control)
        task = {
          "payloads" => config.param("payloads", :array),
          "done_payloads" => config['done_payloads'],
          "url_key_of_payload" => config.param("url_key_of_payload", :string, default: 'url'),
          "crawl_url_regexp" => config.param("crawl_url_regexp", :string, default: nil),
          "reject_url_regexp" => config.param("reject_url_regexp", :string, default: nil),
          "user_agent" => config.param("user_agent", :string, default: nil),
          "obey_robots_txt" => config.param("obey_robots_txt", :bool, default: false),
          "skip_query_strings" => config.param("skip_query_strings", :bool, default: false),
          "add_payload_to_record" => config.param("add_payload_to_record", :bool, default: false),
          "accept_cookies" => config.param("accept_cookies", :bool, default: false),
          "remove_style_on_body" => config.param("remove_style_on_body", :bool, default: false),
          "remove_script_on_body" => config.param("remove_style_on_body", :bool, default: false),
          "delay" => config.param("delay", :integer, default: nil),
          "depth_limit" => config.param("depth_limit", :integer, default: nil),
          "read_timeout" => config.param("read_timeout", :integer, default: nil),
          "redirect_limit" => config.param("redirect_limit", :integer, default: nil),
          "page_limit" => config.param("page_limit", :integer, default: nil),
          "cookies" => config.param("cookies", :hash, default: nil),
        }

        columns = [
          Column.new(0, "url", :string),
          Column.new(1, "title", :string),
          Column.new(2, "body", :string),
          Column.new(3, "time", :timestamp),
          Column.new(4, "code", :long),
          Column.new(5, "response_time", :long),
        ]
        columns << Column.new(6, "payload", :json) if task['add_payload_to_record']

        resume(task, columns, task['payloads'].size, &control)
      end

      def self.resume(task, columns, count, &control)
        task_reports = yield(task, columns, count)

        next_config_diff = { done_payloads: task_reports }
        return next_config_diff
      end

      def init
        @payload = task["payloads"][@index]
        @url_key_of_payload = task["url_key_of_payload"]
        @add_payload_to_record = task["add_payload_to_record"]
        @reject_url_regexp = Regexp.new(task["reject_url_regexp"]) if task['reject_url_regexp']
        @crawl_url_regexp = Regexp.new(task["crawl_url_regexp"]) if task['crawl_url_regexp']
        @remove_style_on_body = task["remove_style_on_body"] if task['remove_style_on_body']
        @remove_script_on_body = task["remove_script_on_body"] if task['remove_script_on_body']
        @page_limit = task["page_limit"] if task['page_limit']

        @option = {
          threads: 1,
          obey_robots_txt: task["obey_robots_txt"],
          skip_query_strings: task["skip_query_strings"],
          accept_cookies: task["accept_cookies"],
        }
        @option[:user_agent] = task['user_agent'] if task['user_agent']
        @option[:delay] = task['delay'] if task['delay']
        @option[:depth_limit] = task['depth_limit'] if task['depth_limit']
        @option[:read_timeout] = task['read_timeout'] if task['read_timeout']
        @option[:redirect_limit] = task['redirect_limit'] if task['redirect_limit']
        @option[:cookies] = task['cookies'] if task['cookies']
        if task['done_payloads']
          @done_payloads = task['done_payloads'].map{ |done_payload| done_payload['done_payload'] }
        end
      end

      def run
        if should_process_payload?(@payload)
          base_url = @payload[@url_key_of_payload]
          Embulk.logger.info("crawling.. => #{base_url}")

          crawl_counter = 0
          Anemone.crawl(base_url, @option) do |anemone|
            anemone.skip_links_like(@reject_url_regexp) if @reject_url_regexp

            anemone.focus_crawl do |page|
              page.links(exclude_nofollow: true).keep_if { |link|
                if @page_limit && (crawl_counter >= @page_limit)
                  false
                else
                  is_crawl = crawl?(link)
                  crawl_counter += 1 if is_crawl
                  is_crawl
                end
              }
            end

            anemone.on_every_page do |page|
              redirect_url = redirect_url(page)
              if redirect_url(page)
                page.links << redirect_url
              else
                record = make_record(page)

                values = schema.map { |column|
                  record[column.name]
                }
                page_builder.add(values)
              end
            end
          end

          page_builder.finish
        end

        task_report = { 'done_payload' => @payload }
        return task_report
      end

      private

      def should_process_payload?(payload)
        if @done_payloads
          if @done_payloads.include?(payload)
            false
          else
            true
          end
        else
          true
        end
      end

      def make_record(page)
        Embulk.logger.debug("url => #{page.url.to_s}")
        doc = page.doc

        record = {}
        record['url'] = page.url.to_s

        record['title'] = get_title(doc)

        record['body'] = get_body(doc)

        record['time'] = Time.now

        record['code'] = page.code

        record['response_time'] = page.response_time

        record['payload'] = @payload if @add_payload_to_record
        record
      end

      def get_title(doc)
        return nil if doc.nil?
        doc.title
      end

      def get_body(doc)
        return nil if doc.nil?
        if @remove_style_on_body
          doc.search('script').each do |script|
            script.content = ''
          end

          doc.search('noscript').each do |script|
            script.content = ''
          end
        end

        if @remove_style_on_body
          doc.search('style').each do |style|
            style.content = ''
          end
        end
        doc.search('body').text.gsub(/([\s])+/, " ")
      end

      def crawl?(link)
        if @crawl_url_regexp
          return @crawl_url_regexp.match(link.to_s) ? true : false
        else
          return true
        end
      end

      def redirect_url(page)
        if page.redirect?
          return page.redirect_to
        end

        doc = page.doc
        if doc
          doc.search('meta').each do |meta|
            if meta.attribute('http-equiv')&.value =~ /(r|R)efresh/
              redirect_url = meta.attribute('content').value.sub(/.*(url|URL)=/, '').strip.split(';')[0]
              unless redirect_url =~ /^http(|s)/
                redirect_url = page.url.to_s.sub(/\/$/, '') + '/' + redirect_url.sub(/^\//, '')
              end
              unless redirect_url.size == redirect_url.bytesize
                redirect_url = URI.encode(redirect_url)
              end
              return URI.parse(redirect_url)
            end
          end
        end
        return nil
      end
    end
  end
end
