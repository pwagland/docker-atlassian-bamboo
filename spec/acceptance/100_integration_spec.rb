describe 'Atlassian Bamboo with Embedded Database' do
  include_examples 'a buildable Docker image', '.', env: ["CATALINA_OPTS=-Xms1024m -Xmx2048m -Djava.security.egd=file:/dev/./urandom -Datlassian.plugins.enable.wait=#{Docker::DSL.timeout}"]

  include_examples 'an acceptable Atlassian Bamboo instance', 'using an embedded database'
end

describe 'Atlassian Bamboo with PostgreSQL 9.3 Database' do
  include_examples 'a buildable Docker image', '.', env: ["CATALINA_OPTS=-Xms1024m -Xmx2048m -Djava.security.egd=file:/dev/./urandom -Datlassian.plugins.enable.wait=#{Docker::DSL.timeout}"]

  include_examples 'an acceptable Atlassian Bamboo instance', 'using a PostgreSQL database' do
    before :all do
      Docker::Image.create fromImage: 'postgres:9.3'
      # Create and run a PostgreSQL 9.3 container instance
      @container_db = Docker::Container.create image: 'postgres:9.3'
      @container_db.start!
      # Wait for the PostgreSQL instance to start
      @container_db.wait_for_output(/PostgreSQL\ init\ process\ complete;\ ready\ for\ start\ up\./)
      # Create JIRA database
      # if ENV['CIRCLECI']
        `docker run --rm --link "#{@container_db.id}:db" postgres:9.3 psql --host "db" --user "postgres" --command "create database bamboodb owner postgres encoding 'utf8';"`
      # else
      #   @container_db.exec ['psql', '--username', 'postgres', '--command', "create database bamboodb owner postgres encoding 'utf8';"]
      # end
    end
    after :all do
      @container_db.kill signal: 'SIGKILL' unless @container_db.nil?
      @container_db.remove force: true, v: true unless @container_db.nil? || ENV['CIRCLECI']
    end
  end
end

describe 'Atlassian Bamboo with MySQL 5.7 Database' do
  include_examples 'a buildable Docker image', '.', env: ["CATALINA_OPTS=-Xms1024m -Xmx2048m -Djava.security.egd=file:/dev/./urandom -Datlassian.plugins.enable.wait=#{Docker::DSL.timeout}"]

  include_examples 'an acceptable Atlassian Bamboo instance', 'using a MySQL database' do
    before :all do
      Docker::Image.create fromImage: 'mysql:5.7'
      # Create and run a MySQL 5.7 container instance
      @container_db = Docker::Container.create image: 'mysql:5.7', env: ['MYSQL_ROOT_PASSWORD=mysecretpassword']
      @container_db.start!
      # Wait for the MySQL instance to start
      @container_db.wait_for_output %r{socket:\ '/var/run/mysqld/mysqld\.sock'\ \ port:\ 3306\ \ MySQL\ Community\ Server\ \(GPL\)}
      # Create JIRA database
      # if ENV['CIRCLECI']
        `docker run --link "#{@container_db.id}:db" mysql:5.7 mysql --host "db" --user=root --password=mysecretpassword --execute 'CREATE DATABASE bamboodb CHARACTER SET utf8 COLLATE utf8_bin;'`
      # else
      #   @container_db.exec ['mysql', '--user=root', '--password=mysecretpassword', '--execute', 'CREATE DATABASE bamboodb CHARACTER SET utf8 COLLATE utf8_bin;']
      # end
    end
    after :all do
      if ENV['CIRCLECI']
        @container_db.kill signal: 'SIGKILL' unless @container_db.nil?
      else
        @container_db.kill signal: 'SIGKILL' unless @container_db.nil?
        @container_db.remove force: true, v: true unless @container_db.nil?
      end
    end
  end
end

describe 'Atlassian Bamboo behind reverse proxy' do
  include_examples 'a buildable Docker image', '.',
    env: [
      "CATALINA_OPTS=-Xms1024m -Xmx2048m -Djava.security.egd=file:/dev/./urandom -Datlassian.plugins.enable.wait=#{Docker::DSL.timeout}",
      "X_PROXY_NAME=#{Docker.info['Name']}",
      'X_PROXY_PORT=1234',
      'X_PROXY_SCHEME=http',
      'X_PATH=/bamboo-path'
    ]

  include_examples 'an acceptable Atlassian Bamboo instance', 'using an embedded database' do
    before :all do
      image = Docker::Image.build_from_dir '.docker/nginx'
      # Create and run a nginx reverse proxy container instance
      @container_proxy = Docker::Container.create image: image.id,
        portBindings: { '80/tcp' => [{ 'HostPort' => '1234' }] },
        links: ["#{@container.id}:container"]
      @container_proxy.start!
      @container_proxy.setup_capybara_url({ tcp: 80 }, '/bamboo-path')
    end
    after :all do
      if ENV['CIRCLECI']
        @container_proxy.kill signal: 'SIGKILL' unless @container_proxy.nil?
      else
        @container_proxy.kill signal: 'SIGKILL' unless @container_proxy.nil?
        @container_proxy.remove force: true, v: true unless @container_proxy.nil?
      end
    end
  end
end
