# 160217

# to make http requests
require 'httparty'
# required only if above throws socket error, getaddrinfo
require 'resolv-replace'
# to parse html response
require 'nokogiri'
# to post on facebook wall using GraphAPI
require 'koala'
# to parse the json data
require 'json'

# getting details from Channeli
# to get your CHANNELI_SESSID, login to Channeli and check cookies
# since you can only apply to the companies opened for your branch, this script will post only about them
secrets = File.readlines('./secrets.txt')
CHANNELI_SESSID = secrets[0].strip
BASE_URI = 'https://channeli.in/'

print "Connecting to Channeli..."

@response = HTTParty.get(BASE_URI + 'placement/company/list/',	cookies: {
	'CHANNELI_SESSID': CHANNELI_SESSID
})

puts "#{@response.code} #{@response.message}"
# puts @response.headers.inspect

if @response.code == 200

	print "Connected. Fetching data..."

	# lets dig into HTML response
	html = Nokogiri::HTML(@response.body)
	rows = html.search('table#t1 tbody').children.search('tr')

	data = Hash.new
	data[:company_count] = rows.length
	data[:company_name] = Array.new
  data[:category] = Array.new
	data[:last_date] = Array.new
	data[:pre_posted] = Array.new

	# check if data is already posted
	if File.exist?('companies.json')
		companies = JSON.parse(File.read('companies.json'))
		pre_posted = companies['company_name']
	else
		pre_posted = Array.new
	end

	# counting only new companies opened
	new_companies = data[:company_count] - pre_posted.length
	company_literal = new_companies == 1 ? 'company' : 'companies'

	rows.each_with_index do |row, i|
    cols = row.children.search('td')
		data[:company_name] << cols[1].content.strip
    data[:category] << cols[2].content.strip
		data[:last_date] << cols[3].content.strip
		if pre_posted.include?(data[:company_name][i])
			data[:pre_posted] << true
		else
			data[:pre_posted] << false
		end
	end

	puts "Done. Total #{data[:company_count]} #{company_literal} found."

	# posting on facebook
	if data[:pre_posted].include?(false)
		print "Posting on Facebook about #{new_companies} new #{company_literal}..."
		# follow these instructions to get access token for two months
    # http://stackoverflow.com/questions/17197970/facebook-permanent-page-access-token
		# this facebook user will be used to post the content, so make sure it don't have friends from outside the campus.
    access_token = secrets[1].strip

		# creating post
		post = "#{new_companies} new #{company_literal} opened for us:\r\n"
		data[:company_count].times do |i|
			unless data[:pre_posted][i]
				post += "- [#{data[:category][i]}] #{data[:company_name][i]} (Last Date: #{data[:last_date][i]})\r\n"
			end
		end
		post += "For more: #{BASE_URI}placement/company/list"

		# using koala gem to post
		@graph = Koala::Facebook::API.new(access_token)
		@graph.put_wall_post(post)

		puts "Done."

		# save it in a json file
		print "saving data to json file..."

		File.open('companies.json', 'w') do |f|
			f.write(data.to_json)
		end

	else
		puts "No new company arrived. Nothing to post on Facebook."
	end

	puts "Done."

else
	puts "Error: Cannot not connect to Channeli!"
end
