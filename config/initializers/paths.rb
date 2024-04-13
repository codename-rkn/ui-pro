if ENV['RKN_PRO_DB_DIR']
    FileUtils.mkdir_p ENV['RKN_PRO_DB_DIR']
end

if ENV['RKN_PRO_LOG_DIR']
    FileUtils.mkdir_p ENV['RKN_PRO_LOG_DIR']
end
