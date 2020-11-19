require 'net/http'
require 'rubygems'
require 'pry'
require 'json'
require 'csv'
require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :selenium_chrome
  config.default_max_wait_time = 30
  config.app_host = 'https://nmlsconsumeraccess.org'
end

Capybara.register_driver :selenium_chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

module CapybaraCaptcha
  class Test
    include Capybara::DSL
    def test_google
      visit '/TuringTestPage.aspx?ReturnUrl=/Home.aspx/SubSearch=?searchText=85035'
      if page.current_path == '/TuringTestPage.aspx'
        if page.has_current_path?('/') && page.has_css?('#searchText')
          a = page.driver.browser.manage.cookie_named('__cfruid')[:value]
          b = page.driver.browser.manage.cookie_named('ASP.NET_SessionId')[:value]
          c = page.driver.browser.manage.cookie_named('__cfduid')[:value]
          d = page.driver.browser.manage.cookie_named('AWSALB')[:value]
          e = page.driver.browser.manage.cookie_named('AWSALBCORS')[:value]
          page.driver.browser.quit
          "__cfruid=#{a}; ASP.NET_SessionId=#{b}; __cfduid=#{c}; AWSALB=#{d}; AWSALBCORS=#{e}"
        end
      end
    end
  end
end

def write_file(file_name, array)
  file_exists = File.file?(file_name)
  File.open(file_name, file_exists ? 'a' : 'w') do |file|
    file.puts(array[0].keys.to_s.tr('\"[]', '')) unless file_exists
    array.map(&:values).each do |single_consumer|
      single_consumer.to_s.tr('\"[]', '')
      file.puts(single_consumer.to_s.tr('\"[]', ''))
    end
  end
end

def headers(req, cookies)
  req['authority'] = 'nmlsconsumeraccess.org'
  req['sec-ch-ua'] = '"Chromium";v="86", "\"Not\\A;Brand";v="99", "Google Chrome";v="86"'
  req['accept'] = "application/json, text/javascript, */*; q=0.01"
  req['x-requested-with'] = 'XMLHttpRequest'
  req['sec-ch-ua-mobile'] = '?0'
  req['user-agent'] = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.111 Safari/537.36'
  req['content-type'] = 'application/json'
  req['sec-fetch-site'] = 'same-origin'
  req['sec-fetch-mode'] = 'cors'
  req['sec-fetch-dest'] = 'empty'
  req['referer'] = 'https://nmlsconsumeraccess.org/Home.aspx/'
  req['accept-language'] = 'en-US,en;q=0.9,uk;q=0.8'
  req['cookie'] = cookies if cookies
end

def capybara_cookies
  test = CapybaraCaptcha::Test.new
  test.test_google
end

session_cookies = capybara_cookies
puts 'Put needed ID (type Q to quit)'
while (id = gets.chomp) != 'q'
  companies = []
  individuals = []
  uri = URI("https://nmlsconsumeraccess.org/Home.aspx/SubSearch?searchText=#{id}&entityType=&state=&page=1&_=1604487847550")
  req = Net::HTTP::Get.new(uri)
  headers(req, session_cookies)
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
  total_page_count = JSON(res.body)['Data']['PageCount'] || 1
  (1..total_page_count).each do |new_page|
    uri1 = URI("https://nmlsconsumeraccess.org/Home.aspx/SubSearch?searchText=#{id}&entityType=&state=&page=#{new_page}&_=1604487847550")
    req1 = Net::HTTP::Get.new(uri1)
    headers(req1, session_cookies)
    res1 = Net::HTTP.start(uri1.hostname, uri1.port, use_ssl: uri1.scheme == 'https') { |http1|
      http1.request(req1)
    }
    if JSON(res1.body)['Data']['Page'] != new_page
      puts 'Please, update your cookies!'
      break
    else
      JSON(res1.body)['Data']['Entities'].each do |array|
        case array['EntityType']
        when 'COMPANY'
          companies.push(array)
        when 'INDIVIDUAL'
          individuals.push(array)
        end
      end
      sleep 3
    end
  end
  write_file('companies.csv', companies) unless companies.empty?
  puts "Wrote #{companies.length} companies into document companies.csv"
  write_file('individuals.csv', individuals) unless individuals.empty?
  puts "Wrote #{individuals.length} individuals into document individuals.csv"
  puts '----------------------'
  puts 'Enter id again | Type q to quit'
end
