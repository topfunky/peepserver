
class Capistrano::Configuration

  ##
  # Path to the directory with the rails-runit/service directory.

  def shared_runit_service_path
    File.join(shared_path, "rails-runit", "service")
  end

  def install_runit_service(service_name)
    single_service_path = File.join(shared_runit_service_path, service_name)
    run "mkdir -p #{single_service_path}"
    upload local_template_file_path("runit/#{service_name}"), "#{single_service_path}/run", :mode => 0755
    run "ln -s #{single_service_path} ~/service/"
  end

end

namespace :peepcode do

  namespace :runit do

    desc "Install runit tasks for the current Rails app, using thin and Ruby enterprise.\nDo this before other peepcode:runit tasks."
    task :rails do
      cmd = [
        "cd #{shared_path}",
        "git clone git://github.com/purcell/rails-runit.git",
        "cd rails-runit",
        "ln -s /opt/ruby-enterprise/bin/thin thin",
        "ln -s #{current_path} app"
      ].join(" && ")
      run cmd

      # Add runit task for all thin ports
      (mongrel_port...(mongrel_port + mongrel_servers)).each do |port_number|
        run "cd #{shared_path}/rails-runit && ./add-thin #{port_number}"
        run "ln -s #{shared_runit_service_path}/thin-#{port_number} ~/service"
      end
    end


    desc "Install runit task for beanstalk"
    task :beanstalkd do
      install_runit_service("beanstalkd")
    end

    desc "Install beanstalk worker for async-observer plugin"
    task :async_observer do
      async_observer_service_path = File.join(shared_runit_service_path, "#{application}-async_observer")
      run "mkdir -p #{async_observer_service_path}"

      result = render_erb_template(File.dirname(__FILE__) + "/templates/runit/async_observer_worker.erb")
      put result, "#{async_observer_service_path}/run", :mode => 0755
      run "ln -s #{async_observer_service_path} ~/service/"

      inform "Add this callback to your deploy.rb:\n\n\tafter 'deploy:restart', 'peepcode:runit:restart_async_observer'"
    end

    desc "Restart async-observer worker for this application"
    task :restart_async_observer do
      # Try to force-restart, then continue if it fails
      run "sv -w 20 force-restart ~/service/#{application}-async_observer; true"
    end

    desc "Install runit task for memcache"
    task :memcached do
      install_runit_service("memcached")
    end

    desc "Dev task"
    task :reset do
      run "rm -rf #{shared_path}/rails-runit"
    end

  end

end
