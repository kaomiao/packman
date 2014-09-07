class Ferret < PACKMAN::Package
  url 'ftp://ftp.pmel.noaa.gov/ferret/pub/source/fer_source.tar.gz'
  sha1 '8290af0fc18df2a6f3552f771a6c5140ef35a256'
  version '6.9'

  depends_on 'readline'
  depends_on 'hdf5'
  depends_on 'netcdf_c'
  depends_on 'netcdf_fortran'
  depends_on 'zlib'
  depends_on 'szip'
  depends_on 'curl'

  attach 'ftp://ftp.pmel.noaa.gov/ferret/pub/data/fer_dsets.tar.gz',
         '4a1e3dfdad94f93a70f0359f3a88f65c342d8d39'

  def install
    # Ferret's tar file contains two extra plain files which messes up PACKMAN.
    PACKMAN.cd 'FERRET'
    ferret = PACKMAN::Package.prefix(self)
    ncurses = PACKMAN::Package.prefix(Ncurses)
    readline = PACKMAN::Package.prefix(Readline)
    hdf5 = PACKMAN::Package.prefix(Hdf5)
    netcdf_c = PACKMAN::Package.prefix(Netcdf_c)
    netcdf_fortran = PACKMAN::Package.prefix(Netcdf_fortran)
    zlib = PACKMAN::Package.prefix(Zlib)
    szip = PACKMAN::Package.prefix(Szip)
    curl = PACKMAN::Package.prefix(Curl)
    # Check build type (Shame on you, Ferret! You can't just automatically
    # judge it!).
    build_type = ''
    if PACKMAN::OS.x86_64?
      case PACKMAN::OS.type
      when :Darwin
        build_type = 'i386-apple-darwin'
      when :Linux
        build_type = 'x86_64-linux'
      end
    else
      case PACKMAN::OS.type
      when :Darwin
        build_type = 'i386-apple-darwin'
      when :Linux
        build_type = 'linux'
      end
    end
    # Change configuration.
    PACKMAN.replace 'site_specific.mk', {
      /^BUILDTYPE\s*=.*$/ => "BUILDTYPE = #{build_type}",
      /^INSTALL_FER_DIR\s*=.*$/ => "INSTALL_FER_DIR = #{ferret}",
      /^HDF5_DIR\s*=.*$/ => "HDF5_DIR = #{hdf5}",
      /^NETCDF4_DIR\s*=.*$/ => "NETCDF4_DIR = #{netcdf_c}",
      /^READLINE_DIR\s*=.*$/ => "READLINE_DIR = #{readline}",
      /^LIBZ_DIR\s*=.*$/ => "LIBZ_DIR = #{zlib}"
    }
    PACKMAN.replace "platform_specific.mk.#{build_type}", {
      /^(\s*INCLUDES\s*=.*)$/ => "\\1\n-I#{netcdf_fortran}/include -I#{curl}/include \\",
      /^(\s*LDFLAGS\s*=.*)$/ => "\\1 -L#{netcdf_fortran}/lib -L#{curl}/lib ",
      /^(\s*TERMCAPLIB\s*=).*$/ => "\\1 -L#{ncurses}/lib -lncurses"
    }
    # Check if Xmu library is installed by system or not.
    xmu_package = ''
    case PACKMAN::OS.distro
    when :Red_Hat_Enterprise
      xmu_package = 'libXmu-devel'
    when :Ubuntu
      xmu_package = 'libxmu-dev'
    else
      PACKMAN.under_construction!
    end
    if not PACKMAN::OS.installed? xmu_package
      PACKMAN.report_warning "System package "+
        "#{PACKMAN::Tty.red}#{xmu_package}#{PACKMAN::Tty.reset} is not "+
        "installed! Macro NO_WIN_UTIL_H will be used."
      PACKMAN.report_warning "If you want Ferret to use WIN_UTIL and you "+
        "have root previledge, you can install #{xmu_package} and come back."
      PACKMAN.replace "platform_specific.mk.#{build_type}", {
        /^(\s*CPP_FLAGS\s*=.*)$/ => "\\1\n-DNO_WIN_UTIL_H \\"
      }
    end
    # Bad Ferret developers! Shame on you!
    PACKMAN.replace 'external_functions/ef_utility/ferret_cmn/EF_mem_subsc_f90.inc', {
      /^\s*EXTERNAL\s*FERRET_EF_MEM_SUBSC\s*$/ => ''
    }
    PACKMAN.replace 'external_functions/ef_utility/ferret_cmn/EF_mem_subsc.cmn', {
      /^\s*EXTERNAL\s*FERRET_EF_MEM_SUBSC\s*$/ => ''
    }
    PACKMAN.replace 'fer/common/EF_mem_subsc.cmn', {
      /^\s*EXTERNAL\s*FERRET_EF_MEM_SUBSC\s*$/ => ''
    }
    PACKMAN.replace "platform_specific.mk.#{build_type}", {
      /lib64/ => 'lib',
      /-Wl,-Bstatic -lgfortran/ => '-Wl,-Bdynamic -lgfortran'
    }
    PACKMAN.replace "platform_specific.mk.#{build_type}", {
      /\$\(NETCDF4_DIR\)\/lib\/libnetcdff\.a/ => "#{netcdf_fortran}/lib/libnetcdff.a",
      /^(\s*\$\(LIBZ_DIR\)\/lib\/libz.a)$/ => "\\1 \\\n#{szip}/lib/libsz.a"
    }
    # BUILDTYPE is not propagated into external_functions directory
    ['contributed', 'examples', 'fft', 'statistics'].each do |dir|
      PACKMAN.replace "external_functions/#{dir}/Makefile", {
        /\$\(BUILDTYPE\)/ => build_type
        }
    end
    # Make.
    PACKMAN.run 'make'
    PACKMAN.run 'make install'
    PACKMAN.cd ferret
    PACKMAN.decompress 'fer_environment.tar.gz'
    PACKMAN.cd File.dirname(ferret)
    PACKMAN.mkdir 'datasets'
    PACKMAN.cd 'datasets'
    datasets = "#{PACKMAN::ConfigManager.package_root}/fer_dsets.tar.gz"
    PACKMAN.decompress datasets
    PACKMAN.cd ferret
    # Do the final installation step.
    PACKMAN.rm 'ferret_paths.csh'
    PACKMAN.rm 'ferret_paths.sh'
    PTY.spawn('unset FER_DIR FER_DSETS; ./bin/Finstall') do |reader, writer, pid|
      reader.expect(/\(1, 2, 3, q, x\) --> /)
      writer.print("2\n")
      reader.expect(/FER_DIR --> /)
      writer.print("#{ferret}\n")
      reader.expect(/FER_DSETS --> /)
      writer.print("#{File.dirname(ferret)}/datasets\n")
      reader.expect(/desired ferret_paths location --> /)
      writer.print("#{ferret}\n")
      reader.expect(/ferret_paths link to create\? \(c\/s\/n\) \[n\] --> /)
      writer.print("n\n")
      reader.expect(/\(1, 2, 3, q, x\) --> /)
      writer.print("q\n")
    end
  end

  def postfix
    # Ferret has put its shell configuration into 'ferret_paths.sh', so we
    # respect it.
    bashrc = "#{PACKMAN::Package.prefix(self)}/bashrc"
    PACKMAN.rm bashrc
    File.open(bashrc, 'w') do |file|
      file << "# #{sha1}\n"
      file << "source #{PACKMAN::Package.prefix(self)}/ferret_paths.sh\n"
    end
  end
end