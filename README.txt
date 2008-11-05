PeepServer plugin for Capistrano.

  by Geoffrey Grosenbach
  Screencast: http://peepcode.com/products/capistrano-2
  
== DESCRIPTION

Provides Capistrano deployment tasks for setting up and maintaining a CentOS server such those installed at RailsMachine (http://railsmachine.com).

Some are highly customized for my current server (nginx, runit, thin, ruby-enterprise). You should customize it for your own situation.

Use at your own risk.

== USAGE

If you use the async-observer plugin and use this plugin to register a runit service for it, you'll also need to register the restart task in your own Capistrano deployment recipe file.

  after "deploy:restart", "peepcode:runit:restart_async_observer"

