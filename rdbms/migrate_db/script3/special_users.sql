GRANT USAGE ON *.* TO `a10hauser`@`%` IDENTIFIED BY PASSWORD '*C8D8854B873E9643403C0EC8BCF6018896874F39';
GRANT SELECT ON `mysql`.`help_topic` TO `a10hauser`@`%`;

GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO `b0071_wi`@`172.30.%` IDENTIFIED BY PASSWORD '*BFA8738152FA601F3EF9C9B5E13F3B923095E50C' WITH MAX_QUERIES_PER_HOUR 500 MAX_UPDATES_PER_HOUR 100 MAX_CONNECTIONS_PER_HOUR 100 MAX_USER_CONNECTIONS 5;

GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO `b0071_wi`@`172.21.%` IDENTIFIED BY PASSWORD '*BFA8738152FA601F3EF9C9B5E13F3B923095E50C' WITH MAX_QUERIES_PER_HOUR 500 MAX_UPDATES_PER_HOUR 100 MAX_CONNECTIONS_PER_HOUR 100 MAX_USER_CONNECTIONS 5;

GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO `b0071_wi`@`172.26.%` IDENTIFIED BY PASSWORD '*BFA8738152FA601F3EF9C9B5E13F3B923095E50C' WITH MAX_QUERIES_PER_HOUR 500 MAX_UPDATES_PER_HOUR 100 MAX_CONNECTIONS_PER_HOUR 100 MAX_USER_CONNECTIONS 5;

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, SUPER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER ON *.* TO `innobackupex`@`localhost` IDENTIFIED BY PASSWORD '*C5C93C1102AE90981600ADEA14FC71E6ACDE8AAA';

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, SUPER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER ON *.* TO `innobackupex`@`10.30.35.169` IDENTIFIED BY PASSWORD '*C5C93C1102AE90981600ADEA14FC71E6ACDE8AAA';

GRANT ALL PRIVILEGES ON *.* TO `ivan`@`172.30.%` IDENTIFIED BY PASSWORD '*3236CD1E7009DD8D0B6AEA280508401CD8891353' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `ivan`@`10.106.2.42` IDENTIFIED BY PASSWORD '*3236CD1E7009DD8D0B6AEA280508401CD8891353' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `ivan`@`172.21.%` IDENTIFIED BY PASSWORD '*3236CD1E7009DD8D0B6AEA280508401CD8891353' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `ivan`@`172.26.%` IDENTIFIED BY PASSWORD '*3236CD1E7009DD8D0B6AEA280508401CD8891353' WITH GRANT OPTION;

GRANT RELOAD, SUPER ON *.* TO `logrotate`@`localhost` IDENTIFIED BY PASSWORD '*87B7DC5D50C3FDE61A98BE659F15029B1CD564FA';

GRANT PROCESS, SUPER, REPLICATION CLIENT ON *.* TO `mmm_agent`@`172.26.%` IDENTIFIED BY PASSWORD '*5DBA5668FEDA2EE0D474942598CB26CE9978E979';

GRANT PROCESS, SUPER, REPLICATION CLIENT ON *.* TO `mmm_agent`@`172.30.%` IDENTIFIED BY PASSWORD '*5DBA5668FEDA2EE0D474942598CB26CE9978E979';

GRANT REPLICATION CLIENT ON *.* TO `mmm_monitor`@`172.26.%` IDENTIFIED BY PASSWORD '*5DBA5668FEDA2EE0D474942598CB26CE9978E979';

GRANT REPLICATION CLIENT ON *.* TO `mmm_monitor`@`172.30.%` IDENTIFIED BY PASSWORD '*5DBA5668FEDA2EE0D474942598CB26CE9978E979';

GRANT RELOAD, PROCESS, SUPER, REPLICATION SLAVE ON *.* TO `orc_client_user`@`172.21.%` IDENTIFIED BY PASSWORD '*C82EB6FC2165DE9AA54DAC3C146440AE909089AE';

GRANT RELOAD, PROCESS, SUPER, REPLICATION SLAVE ON *.* TO `orc_client_user`@`172.30.%` IDENTIFIED BY PASSWORD '*C82EB6FC2165DE9AA54DAC3C146440AE909089AE';

GRANT RELOAD, PROCESS, SUPER, REPLICATION SLAVE ON *.* TO `orc_client_user`@`172.26.%` IDENTIFIED BY PASSWORD '*C82EB6FC2165DE9AA54DAC3C146440AE909089AE';

GRANT ALL PRIVILEGES ON *.* TO `otto`@`10.106.2.34` IDENTIFIED BY PASSWORD '*771D5B73C5AD566BD7D6F652CCC8CD68E1F8F467' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `otto`@`172.26.%` IDENTIFIED BY PASSWORD '*771D5B73C5AD566BD7D6F652CCC8CD68E1F8F467' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `otto`@`172.21.%` IDENTIFIED BY PASSWORD '*771D5B73C5AD566BD7D6F652CCC8CD68E1F8F467' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `otto`@`172.30.%` IDENTIFIED BY PASSWORD '*771D5B73C5AD566BD7D6F652CCC8CD68E1F8F467' WITH GRANT OPTION;

GRANT SELECT, RELOAD, PROCESS, SUPER, REPLICATION CLIENT ON *.* TO `pmm`@`127.0.0.1` IDENTIFIED BY PASSWORD '*92BA61FC1AD424D9C91F0921D422059A15CCEF00' WITH MAX_USER_CONNECTIONS 10;
GRANT UPDATE, DELETE, DROP ON `performance_schema`.* TO `pmm`@`127.0.0.1`;

GRANT SELECT, RELOAD, PROCESS, SUPER, REPLICATION CLIENT ON *.* TO `pmm`@`localhost` IDENTIFIED BY PASSWORD '*92BA61FC1AD424D9C91F0921D422059A15CCEF00' WITH MAX_USER_CONNECTIONS 10;
GRANT UPDATE, DELETE, DROP ON `performance_schema`.* TO `pmm`@`localhost`;

GRANT USAGE ON *.* TO `proxysql_monitor`@`172.30.%` IDENTIFIED BY PASSWORD '*1D668F8AADED63707D42585239EAA2AD215C2B07';

GRANT USAGE ON *.* TO `proxysql_monitor`@`172.21.%` IDENTIFIED BY PASSWORD '*1D668F8AADED63707D42585239EAA2AD215C2B07';

GRANT USAGE ON *.* TO `proxysql_monitor`@`172.26.%` IDENTIFIED BY PASSWORD '*1D668F8AADED63707D42585239EAA2AD215C2B07';

GRANT REPLICATION SLAVE ON *.* TO `replication`@`172.26.%` IDENTIFIED BY PASSWORD '*A424E797037BF97C19A2E88CF7891C5C2038C039';

GRANT REPLICATION SLAVE ON *.* TO `replication`@`172.30.%` IDENTIFIED BY PASSWORD '*A424E797037BF97C19A2E88CF7891C5C2038C039';

GRANT REPLICATION SLAVE ON *.* TO `replication`@`10.144.%` IDENTIFIED BY PASSWORD '*A424E797037BF97C19A2E88CF7891C5C2038C039';

GRANT SELECT, PROCESS, SUPER, LOCK TABLES, REPLICATION SLAVE ON *.* TO `replication`@`172.21.%` IDENTIFIED BY PASSWORD '*A424E797037BF97C19A2E88CF7891C5C2038C039';
GRANT ALL PRIVILEGES ON `percona`.* TO `replication`@`172.21.%`;

GRANT SELECT, PROCESS, SUPER, SHOW VIEW ON *.* TO `sqltrace`@`172.30.%` IDENTIFIED BY PASSWORD '*96FF0CBB8D23472EB0B202C12ED536D76CB591D2' WITH GRANT OPTION;

GRANT SELECT, PROCESS, SUPER, SHOW VIEW ON *.* TO `sqltrace`@`172.26.%` IDENTIFIED BY PASSWORD '*96FF0CBB8D23472EB0B202C12ED536D76CB591D2' WITH GRANT OPTION;

GRANT SELECT, PROCESS, SUPER, SHOW VIEW ON *.* TO `sqltrace`@`172.21.%` IDENTIFIED BY PASSWORD '*96FF0CBB8D23472EB0B202C12ED536D76CB591D2' WITH GRANT OPTION;

GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO `sstuser`@`localhost` IDENTIFIED BY PASSWORD '*A203716849283DB5DDA702B3DEF873055D972E74';

GRANT USAGE ON *.* TO `webmonitor`@`172.26.%` IDENTIFIED BY PASSWORD '*814948F6DBBCFAD17CC83362159526BDEEF5E65B';

GRANT USAGE ON *.* TO `webmonitor`@`172.30.%` IDENTIFIED BY PASSWORD '*814948F6DBBCFAD17CC83362159526BDEEF5E65B';

GRANT ALL PRIVILEGES ON *.* TO `wnlin`@`172.30.%` IDENTIFIED BY PASSWORD '*38761748B30F1122BDB93B9EDEAAB9A0FA6CFDD4' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `wnlin`@`10.106.2.36` IDENTIFIED BY PASSWORD '*38761748B30F1122BDB93B9EDEAAB9A0FA6CFDD4' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `wnlin`@`172.26.%` IDENTIFIED BY PASSWORD '*38761748B30F1122BDB93B9EDEAAB9A0FA6CFDD4' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO `wnlin`@`172.21.%` IDENTIFIED BY PASSWORD '*38761748B30F1122BDB93B9EDEAAB9A0FA6CFDD4' WITH GRANT OPTION;

