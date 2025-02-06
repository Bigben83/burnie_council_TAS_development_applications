require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'date'

# Initialize the logger
logger = Logger.new(STDOUT)

# Define the URL of the page
url = 'https://www.burnie.tas.gov.au/Development/Planning/Permit-applications-on-exhibition'

# Step 1: Fetch the page content
begin
  logger.info("Fetching page content from: #{url}")
  page_html = open(url).read
  logger.info("Successfully fetched page content.")
rescue => e
  logger.error("Failed to fetch page content: #{e}")
  exit
end

# Step 2: Parse the page content using Nokogiri
doc = Nokogiri::HTML(page_html)

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

# Create table
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS burnie (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_scraped TEXT,
    date_received TEXT,
    on_notice_to TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    owner TEXT,
    stage_description TEXT,
    stage_status TEXT,
    document_description TEXT,
    title_reference TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
title_reference = ''
date_received = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = Date.today.to_s

# Step 5: Extract data for each application
doc.css('article').each_with_index do |row, index|
  # Extract title (council_reference)
  council_reference = row.at_css('.da-application-number.small-text').text.strip
  description = row.at_css('.list-item-title').text.strip
  address = row.at_css('.list-item-address').text.strip

  # Extract on_notice_to date (from the "On display until" text)
  on_notice_to = row.at_css('.applications-closing.display-until.small-text.display-until-date').text.strip
  on_notice_to = on_notice_to.match(/\d{1,2} [A-Za-z]+ \d{4}/)&.captures&.first  # Extract only the date part (e.g., 11 February 2025)
  # on_notice_to = Date.strptime(on_notice_to, "%d %B %Y").to_s  # Convert to ISO 8601 format

  # Extract document URL
  document_description = row.at_css('a')['href']

  # Log the extracted data for debugging purposes
  logger.info("Extracted Data: Title: #{description}, Council Reference: #{council_reference}, Address: #{address}, On Notice To: #{on_notice_to}, Document URL: #{document_description}")

  # Step 6: Ensure the entry does not already exist before inserting
  existing_entry = db.execute("SELECT * FROM burnie WHERE council_reference = ?", council_reference)

  if existing_entry.empty?  # Only insert if the entry doesn't already exist
    # Save data to the database
    db.execute("INSERT INTO burnie 
      (description, date_scraped, date_received, on_notice_to, address, council_reference, applicant, owner, stage_description, stage_status, document_description, title_reference) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      [description, date_scraped, date_received, on_notice_to, address, council_reference, applicant, owner, stage_description, stage_status, document_description, title_reference])

    logger.info("Data for #{council_reference} saved to database.")
  else
    logger.info("Duplicate entry for document #{council_reference} found. Skipping insertion.")
  end
end
