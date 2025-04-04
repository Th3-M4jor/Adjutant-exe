CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" INTEGER PRIMARY KEY, "inserted_at" TEXT_DATETIME);
CREATE TABLE IF NOT EXISTS "banlist" ("id" INTEGER PRIMARY KEY, "added_by" INTEGER NOT NULL, "to_ban" INTEGER NOT NULL, "inserted_at" TEXT_DATETIME NOT NULL);
CREATE TABLE IF NOT EXISTS "created_commands" ("name" TEXT NOT NULL PRIMARY KEY, "state" BLOB NOT NULL, "inserted_at" TEXT_DATETIME NOT NULL, "updated_at" TEXT_DATETIME NOT NULL, "cmd_ids" BLOB);
CREATE TABLE IF NOT EXISTS "oban_jobs" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "state" TEXT DEFAULT 'available' NOT NULL, "queue" TEXT DEFAULT 'default' NOT NULL, "worker" TEXT NOT NULL, "args" JSON DEFAULT ('{}') NOT NULL, "meta" JSON DEFAULT ('{}') NOT NULL, "tags" JSON DEFAULT ('[]') NOT NULL, "errors" JSON DEFAULT ('[]') NOT NULL, "attempt" INTEGER DEFAULT 0 NOT NULL, "max_attempts" INTEGER DEFAULT 20 NOT NULL, "priority" INTEGER DEFAULT 0 NOT NULL, "inserted_at" TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL, "scheduled_at" TEXT DEFAULT CURRENT_TIMESTAMP NOT NULL, "attempted_at" TEXT, "attempted_by" JSON DEFAULT ('[]') NOT NULL, "cancelled_at" TEXT, "completed_at" TEXT, "discarded_at" TEXT);
CREATE TABLE sqlite_sequence(name,seq);
CREATE INDEX "oban_jobs_state_queue_priority_scheduled_at_id_index" ON "oban_jobs" ("state", "queue", "priority", "scheduled_at", "id");
INSERT INTO schema_migrations VALUES(20211003173517,'2021-10-03T18:33:03');
INSERT INTO schema_migrations VALUES(20211015184140,'2021-10-15T19:41:05');
INSERT INTO schema_migrations VALUES(20220612195711,'2022-06-12T20:07:30');
INSERT INTO schema_migrations VALUES(20220626160455,'2022-06-26T19:56:01');
INSERT INTO schema_migrations VALUES(20220813171203,'2022-08-13T17:13:03');
INSERT INTO schema_migrations VALUES(20230516030631,'2023-05-16T03:10:22');
INSERT INTO schema_migrations VALUES(20230629015706,'2023-06-29T01:59:05');
INSERT INTO schema_migrations VALUES(20231117044416,'2023-11-17T04:45:10');
INSERT INTO schema_migrations VALUES(20240525001633,'2024-05-25T00:18:20');
INSERT INTO schema_migrations VALUES(20240719024733,'2024-07-19T02:49:32');
