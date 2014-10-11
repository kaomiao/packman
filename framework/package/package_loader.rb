module PACKMAN
  class PackageLoader
    # Collect package definition files.
    @@package_files = {}
    tmp = Dir.glob("#{ENV['PACKMAN_ROOT']}/packages/*.rb")
    tmp.delete("#{ENV['PACKMAN_ROOT']}/packages/packman_packages.rb")
    tmp.each do |file|
      name = File.basename(file).split('.').first.capitalize.to_sym
      @@package_files[name] = file
    end

    # Define a recursive function to load package definition files.
    def self.load_package package_name, install_spec = nil
      load @@package_files[package_name]
      if install_spec
        package = Package.instance package_name, install_spec
        install_spec.each do |key, value|
          if package.options.has_key? key
            case package.option_valid_types[key]
            when :package_name
              if (not value.class == String and not value.class == Symbol) or not Package.defined? value
                CLI.report_error "Option #{CLI.red key} for #{CLI.red package_name} should be set to a valid package name!"
              end
            when :boolean
              if not !!value == value
                CLI.report_error "Option #{CLI.red key} for #{CLI.red package_name} should be set to a boolean!"
              end
            end
            package.options[key] = value
          end
        end
      else
        package = Package.instance package_name
      end
      package.dependencies.each do |depend_name|
        next if depend_name == :package_name # Skip the placeholder :package_name.
        load @@package_files[depend_name]
        depend_package = Package.instance depend_name
        package.options.each do |key, value|
          if depend_package.options.has_key? key
            depend_package.options[key] = value
          end
        end
        load_package depend_name, nil if not depend_package.options.empty?
      end
    end

    def self.init
      ConfigManager.packages.each do |package_name, install_spec|
        load_package package_name, install_spec
      end
    end
  end
end