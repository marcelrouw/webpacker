REGEX_MAP = /\A.*\.map\z/

namespace :webpacker do
  desc "Compile javascript packs using webpack for production with digests"
  task :compile => :environment do
    Rails.logger.debug "webpacker start task compile"
    dist_dir = Rails.application.config.x.webpacker[:packs_dist_dir]
    result   = `WEBPACK_DIST_DIR=#{dist_dir} NODE_ENV=production ./bin/webpack --json`

    Rails.logger.debug "pass 1 webpacker --json #{$?} - #{$?.success?}: #{result[0..200]}"
    result = result[result.index("\n")..result.length]
    Rails.logger.debug "pass 2 webpacker --json #{$?} - #{$?.success?}: #{result[0..200]}"

    unless $?.success?
      Rails.logger.debug "unless 1: #{$?.exitstatus}"
      puts JSON.parse(result)['errors']
      Rails.logger.debug "unless 2: #{$?.exitstatus}"
      exit! $?.exitstatus
    end

    Rails.logger.debug "webpack_digests: before"

    webpack_digests = JSON.parse(result)['assetsByChunkName'].each_with_object({}) do |(chunk, file), h|
      h[chunk] = file.is_a?(Array) ? file.find {|f| REGEX_MAP !~ f } : file
    end.to_json

    digests_path = Rails.application.config.x.webpacker[:digests_path]
    packs_path = Rails.root.join('public', dist_dir) || File.dirname(digests_path)
    packs_digests_path = digests_path || Rails.root.join(packs_path, 'digests.json')

    FileUtils.mkdir_p(packs_path)
    File.open(packs_digests_path, 'w+') { |file| file.write webpack_digests }

    puts "Compiled digests for all packs in #{packs_digests_path}: "
    puts webpack_digests
  end
end

# Compile packs after we've compiled all other assets during precompilation
if Rake::Task.task_defined?('assets:precompile')
  Rake::Task['assets:precompile'].enhance do
    Rake::Task['webpacker:compile'].invoke
  end
end
