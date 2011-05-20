module Jekyll
  module S3
    class Uploader

      SITE_DIR = "_site"
      CONFIGURATION_FILE = '_jekyll_s3.yml'
      CONFIGURATION_FILE_TEMPLATE = <<-EOF
s3_id: YOUR_AWS_S3_ACCESS_KEY_ID
s3_secret: YOUR_AWS_S3_SECRET_ACCESS_KEY
s3_bucket: your.blog.bucket.com
      EOF
        

      def self.run!
        new.run!
      end

      def run!
        check_jekyll_project!
        check_s3_configuration!
        upload_to_s3!
      end

      protected

      # Please spec me!
      def upload_to_s3!
        puts "Uploading _site/* to #{@s3_bucket}"

        storage = Fog::Storage.new(
          :provider               => 'AWS',
          :aws_access_key_id      => @s3_id,
          :aws_secret_access_key  => @s3_secret
        )
        unless directory = storage.directories.get(@s3_bucket)
          puts("Creating bucket #{@s3_bucket}")
          directory = storage.directories.create(
            :key    => @s3_bucket,
            :public => true
          )
        end

        local_files = Dir[SITE_DIR + '/**/*'].
          delete_if { |f| File.directory?(f) }.
          map { |f| f.gsub(SITE_DIR + '/', '') }

        remote_files = []
        # use each for auto-pagination
        directory.files.each do |file|
          remote_files << file.key
        end

        to_upload = local_files
        to_upload.each do |f|
          directory.files.create(
            :body => File.open("#{SITE_DIR}/#{f}"),
            :public => true
          )
          puts("Upload #{f}: Success!")
        end

        to_delete = remote_files - local_files

        delete_all = false
        keep_all = false
        to_delete.each do |f| 
          delete = false
          keep = false
          until delete || delete_all || keep || keep_all
            puts "#{f} is on S3 but not in your _site directory anymore. Do you want to [d]elete, [D]elete all, [k]eep, [K]eep all?"
            case STDIN.gets.chomp
            when 'd' then delete = true
            when 'D' then delete_all = true
            when 'k' then keep = true
            when 'K' then keep_all = true
            end
          end
          if (delete_all || delete) && !(keep_all || keep)
            directory.files.new(:key => f).destroy # use new to avoid API lookup
            puts("Delete #{f}: Success!")
          end
        end

        puts "Done! Go visit: http://#{@s3_bucket}.s3.amazonaws.com/index.html"
      end

      def check_jekyll_project!
        raise NotAJekyllProjectError unless File.directory?(SITE_DIR)
      end

      # Raise NoConfigurationFileError if the configuration file does not exists
      # Raise MalformedConfigurationFileError if the configuration file does not contain the keys we expect
      # Loads the configuration if everything looks cool
      def check_s3_configuration!
        unless File.exists?(CONFIGURATION_FILE)
          create_template_configuration_file
          raise NoConfigurationFileError
        end
        raise MalformedConfigurationFileError unless load_configuration
      end

      # Load configuration from _jekyll_s3.yml
      # Return true if all values are set and not emtpy
      def load_configuration
        config = YAML.load_file(CONFIGURATION_FILE) rescue nil
        return false unless config

        @s3_id = config['s3_id']
        @s3_secret = config['s3_secret']
        @s3_bucket = config['s3_bucket']

        [@s3_id, @s3_secret, @s3_bucket].select { |k| k.nil? || k == '' }.empty?
      end

      def create_template_configuration_file
        File.open(CONFIGURATION_FILE, 'w') { |f| f.write(CONFIGURATION_FILE_TEMPLATE) }

      end
    end
  end
end
