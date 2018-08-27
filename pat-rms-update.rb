require 'csv'
require 'json'
require 'mechanize'
require 'rubygems'

# you may need to change the location of your pat config
PATFILE = "#{Dir.home}/.wl2k/config.json"
URL = 'https://cms.winlink.org:444/GatewayChannels.aspx'

CALL = 1
BASECALL = 2
FREQ = 4
QTH = 8

# get latest ARDOP stations using http
agent = Mechanize.new
agent.get(URL)

# get form and button
myform = agent.page.form_with :id => 'form1'
myform.radiobutton_with(name: 'rblModes', value: 'ARDOP').check
mybutton = myform.button_with(value: "CSV File")

# submit form
agent.submit(myform, mybutton)
csvdata = agent.page.body

# remove formatting
# subtract 1.5 KHz from pub freq for USB
def fix_freq(strfreq)
  khz = strfreq.split()[0].tr(",", "").to_f
  khz - 1.5
end

# loop over csv and create a connect_aliases hash
# store telnet first
result = {}
result.store("telnet","telnet://{mycall}:CMSTelnet@cms.winlink.org:8772/wl2k")
first = true

CSV.parse(csvdata) do |row|
  # skip header
  if first then
    first = false
  else
    result.store("#{row[BASECALL]} (#{fix_freq(row[FREQ])}) #{row[QTH]}","ardop:///#{row[CALL]}?freq=#{fix_freq(row[FREQ])}")
  end
end

# load existing Pat config
pfile = File.read(PATFILE)
config_hash = JSON.parse(pfile)

# replace the old aliases list
config_hash["connect_aliases"] = result

# backup old file
File.write("#{PATFILE}-#{Time.now.strftime("%Y-%m-%d-%H:%M:%S")}", File.read(PATFILE))

# save the config
File.open(PATFILE,"w") do |file|
  file.write JSON.pretty_generate(config_hash)
end
