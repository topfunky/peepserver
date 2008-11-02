
class Capistrano::Configuration

  ##
  # Print an informative message with asterisks.

  def inform(message)
    puts "#{'*' * (message.length + 4)}"
    puts "* #{message} *"
    puts "#{'*' * (message.length + 4)}"
  end

  ##
  # Read a file and evaluate it as an ERB template.
  # Path is relative to this file's directory.

  def render_erb_template(filename)
    template = File.read(filename)
    result   = ERB.new(template).result(binding)
  end

  ##
  # Run a command and return the result as a string.
  #
  # TODO May not work properly on multiple servers.

  def run_and_return(cmd)
    output = []
    run cmd do |ch, st, data|
      output << data
    end
    return output.to_s
  end

end


##
# Custom installation tasks for CentOS (RailsMachine).
#
# Author: Geoffrey Grosenbach http://topfunky.com
#         November 2007

namespace :peepcode do

  desc "Copy config files"
  task :copy_config_files do
    run "cp #{shared_path}/config/* #{release_path}/config/"
  end
  after "deploy:update_code", "peepcode:copy_config_files"

  desc "Generate spin script from variables"
  task :generate_spin_script, :roles => :app do
    result = render_erb_template(File.dirname(__FILE__) + "/templates/spin.erb")
    put result, "#{release_path}/script/spin", :mode => 0755
  end
  after "deploy:update_code", "peepcode:generate_spin_script"

  desc "Make spin script executable"
  task :make_spin_script_executable, :roles => :app do
    run "cd #{current_path} && chmod +x script/spin"
  end
  before "deploy:start", "peepcode:make_spin_script_executable"

  desc "Create shared/config directory and default database.yml."
  task :create_shared_config do
    run "mkdir -p #{shared_path}/config"

    # Copy database.yml if it doesn't exist.
    result = run_and_return "ls #{shared_path}/config"
    unless result.match(/database\.yml/)
      contents = render_erb_template(File.dirname(__FILE__) + "/templates/database.yml")
      put contents, "#{shared_path}/config/database.yml"
      inform "Please edit database.yml in the shared directory."
    end
  end
  after "deploy:setup", "peepcode:create_shared_config"

  namespace :setup do

    desc "Setup Nginx vhost config"
    task :nginx_vhost, :roles => :app do
      result = render_erb_template(File.dirname(__FILE__) + "/templates/nginx.vhost.conf.erb")
      put result, "/tmp/nginx.vhost.conf"
      sudo "mkdir -p /usr/local/nginx/conf/vhosts"
      sudo "cp /tmp/nginx.vhost.conf /usr/local/nginx/conf/vhosts/#{application}.conf"
      inform "You must edit nginx.conf to include the vhost config file."
    end

  end

  namespace :install do

    desc "Install server software"
    task :default do
      setup

      # TODO
      # * Uninstall httpd: chkconfig --del httpd

      runit
      git
      nginx
      memcached
      munin
      httperf
      emacs
      tree
      special_gems
      set_time_to_utc
    end
    
    task :setup do
      # sudo "rm -rf src"
      run  "mkdir -p src"
    end

    desc "Install Ruby 1.8.6"
    task :ruby do
      readline_prereq
      cmd = [
        "cd src",
        "wget ftp://ftp.ruby-lang.org/pub/ruby/1.8/ruby-1.8.6-p111.tar.gz",
        "tar xfz ruby-1.8.6-p111.tar.gz",
        "cd ruby-1.8.6-p111",
        "./configure --prefix=/usr/local --with-readline-dir=/usr/local",
        "make clean",
        "make"
      ].join(" && ")
      run cmd
      sudo "bash -c 'cd src/ruby-1.8.6-p111 && make install'"
    end

    desc "Install readline"
    task :readline_prereq do
      cmd = [
        "cd src",
        "wget ftp://ftp.gnu.org/gnu/readline/readline-5.2.tar.gz",
        "tar xfz readline-5.2.tar.gz",
        "cd readline-5.2",
        "./configure --prefix=/usr/local",
        "make clean",
        "make"
      ].join(" && ")
      run cmd
      sudo "bash -c 'cd src/readline-5.2 && make install'"
    end

    desc "Rubygems 1.0.1"
    task :rubygems do
      cmd = [
        "cd src",
        "wget http://rubyforge.org/frs/download.php/43985/rubygems-1.3.0.tgz",
        "tar xfz rubygems-1.3.0.tgz",
      ].join(" && ")
      run cmd
      sudo "bash -c 'cd src/rubygems-1.3.0 && /usr/local/bin/ruby setup.rb'"
    end

    desc "Install git"
    task :git do
      curl
      cmd = [
        "cd src",
        "wget http://kernel.org/pub/software/scm/git/git-1.5.6.rc3.tar.gz",
        "tar xfz git-1.5.6.rc3.tar.gz",
        "cd git-1.5.6.rc3",
        "make prefix=/usr/local all",
        "sudo make prefix=/usr/local install"
      ].join(" && ")
      run cmd
    end

    desc "Install curl"
    task :curl do
      if run_and_return("which curl") =~ /curl/
        # HACK Run a sudo command so the password is cached
        #      for future commands
        sudo "ls"
      else
        sudo "yum install curl curl-devel -y"
      end
    end

    desc "Install nginx"
    task :nginx do

      result = File.read(File.dirname(__FILE__) + "/templates/install-nginx.sh")
      put result, "src/install-nginx.sh"

      cmd = [
        "cd src",
        "sudo sh install-nginx.sh",
        "wget http://topfunky.net/svn/shovel/nginx/conf/nginx.conf"
      ].join(" && ")
      run cmd
    end

    desc "Install runit"
    task :runit do
      %w(install-runit.sh install-runit-for-user.sh).each do |filename|
        result = File.read(File.dirname(__FILE__) + "/templates/#{filename}")
        put result, "src/#{filename}", :mode => 0755
      end

      sudo "src/install-runit.sh"
      # netcat is used by some scripts
      sudo "yum install nc -y"

      run "src/install-runit-for-user.sh"
    end

    desc "Install memcached"
    task :memcached do
      # TODO Needs to run ldconfig after libevent is installed
      run "echo '/usr/local/lib' > ~/src/memcached-i386.conf"
      sudo "mv ~/src/memcached-i386.conf /etc/ld.so.conf.d/memcached-i386.conf"
      sudo "/sbin/ldconfig"

      result = File.read(File.dirname(__FILE__) + "/templates/install-memcached-linux.sh")
      put result, "src/install-memcached-linux.sh"

      cmd = [
        "cd src",
        "sudo sh install-memcached-linux.sh"
      ].join(" && ")
      run cmd
    end

    desc "Install emacs"
    task :emacs do
      sudo "yum install emacs -y"
    end

    desc "Install gems needed by PeepCode"
    task :special_gems do
      run "ruby -v"
      %w(merb hpricot mongrel mongrel_cluster thin libxml-ruby gruff sparklines ar_mailer bong production_log_analyzer eventmachine amqp xmpp4r json rmagick).each do |gemname|
        sudo "gem install #{gemname} --no-rdoc --no-ri"
      end
      sudo "gem install mysql -- --with-mysql-lib=/usr/lib/mysql --with-mysql-include=/usr/include/mysql"
    end

    desc "Install munin"
    task :munin do
      sudo "rpm -Uhv http://apt.sw.be/packages/rpmforge-release/rpmforge-release-0.3.6-1.el4.rf.i386.rpm"
      sudo "yum install munin munin-node -y"
      post_munin
      munin_plugins
    end

    desc "Post-Munin Tasks"
    task :post_munin do
      cmds = [
        "rm -rf /var/www/munin",
        "mkdir -p /var/www/html/munin",
        "chown munin:munin /var/www/html/munin",
        "/sbin/service munin-node restart"
      ]
      cmds.each do |cmd|
        sudo cmd
      end

      inform "You must link /var/www/html/munin to a web-accessible location."
    end

    desc "Upload and configure desired plugins for munin."
    task :munin_plugins do
      # Reset
      sudo "rm -f /etc/munin/plugins/*"

      # Upload
      put File.read(File.dirname(__FILE__) + "/templates/memcached_"), "/tmp/memcached_"
      sudo "cp /tmp/memcached_ /usr/share/munin/plugins/memcached_"
      sudo "chmod 755 /usr/share/munin/plugins/memcached_"

      # Configure
      {
        "cpu" => "cpu",
        "df" => "df",
        "fw_packets" => "fw_packets",
        "if_eth0" => "if_",
        "if_eth1" => "if_",
        "load" => "load",
        "memcached_bytes" => "memcached_",
        "memcached_counters" => "memcached_",
        "memcached_rates" => "memcached_",
        "memory" => "memory",
        "mysql_bytes" => "mysql_bytes",
        "mysql_queries" => "mysql_queries",
        "mysql_slowqueries" => "mysql_slowqueries",
        "mysql_threads" => "mysql_threads",
        "netstat" => "netstat",
        "ping_nubyonrails.com" => "ping_",
        "ping_peepcode.com" => "ping_",
        "ping_staging.topfunky.railsmachina.com" => "ping_",
        "ping_rubyonrailsworkshops.com" => "ping_",
        "ping_theonlineceo.com" => "ping_",
        "ping_topfunky.com" => "ping_",
        "processes" => "processes",
        "swap" => "swap",
        "users" => "users",
      }.each do |name, source|
        sudo "ln -s /usr/share/munin/plugins/#{source} /etc/munin/plugins/#{name}"
      end
      sudo "/sbin/service munin-node restart"
      sudo "-u munin munin-cron"

      inform "You must may need to run: sudo cpan Cache::Memcached"
    end

    desc "Install httperf"
    task :httperf do
      cmd = [
        "cd src",
        "wget ftp://ftp.hpl.hp.com/pub/httperf/httperf-0.9.0.tar.gz",
        "tar xfz httperf-0.9.0.tar.gz",
        "cd httperf-0.9.0",
        "./configure --prefix=/usr/local",
        "make",
        "sudo make install"
      ].join(' && ')
      run cmd
    end

    desc "Install command-line directory lister"
    task :tree do
      cmd = [
        "cd src",
        "wget ftp://mama.indstate.edu/linux/tree/tree-1.5.1.1.tgz",
        "tar xfz tree-1.5.1.1.tgz",
        "cd tree-1.5.1.1",
        "make",
        "sudo make install"
      ].join(' && ')
      run cmd
    end

    desc "Set time to UTC"
    task :set_time_to_utc do
      sudo "ln -nfs /usr/share/zoneinfo/UTC /etc/localtime"
    end

    desc "Install newer version of make"
    task :make do
      cmd = [
        "cd src",
        "wget http://ftp.gnu.org/pub/gnu/make/make-3.81.tar.gz",
        "tar xfz make-3.81.tar.gz",
        "cd make-3.81",
        "./configure --prefix=/usr/local",
        "make",
        "sudo make install"
      ].join(" && ")
      run cmd
    end


    desc "Install beanstalk in-memory queue"
    task :beanstalk do
      # TODO Bail unless make 3.81 is installed
      cmd = [
        "cd src",
        "wget http://xph.us/software/beanstalkd/rel/beanstalkd-1.0.tar.gz",
        "tar xfz beanstalkd-1.0.tar.gz",
        "cd beanstalkd-1.0",
        "/usr/local/bin/make",
        "sudo cp beanstalkd /usr/local/bin/"
      ].join(" && ")
      run cmd
    end

    desc "Upgrade to Ruby 1.8.6 and newest RubyGems"
    task :upgrade do
      setup
      # ruby
      sudo "gem update --system --no-rdoc --no-ri --no-update-sources"
      sudo "gem install rails --include-dependencies"
      special_gems
      run "ruby -v"
      run "gem list | grep rails"
    end

  end

end
