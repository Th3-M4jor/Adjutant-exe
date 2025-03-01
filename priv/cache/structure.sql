CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" INTEGER PRIMARY KEY, "inserted_at" TEXT);
CREATE TABLE IF NOT EXISTS "messages" ("message_id" TEXT PRIMARY KEY, "channel_id" TEXT, "author_id" TEXT, "data" BLOB);
CREATE INDEX "messages_channel_id_author_id_message_id_index" ON "messages" ("channel_id", "author_id", "message_id");
CREATE INDEX "messages_author_id_message_id_index" ON "messages" ("author_id", "message_id");
CREATE INDEX "messages_channel_id_message_id_index" ON "messages" ("channel_id", "message_id");
INSERT INTO schema_migrations VALUES(20250301000350,'2025-03-01T00:14:06');
