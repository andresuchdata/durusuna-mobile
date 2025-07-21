/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = function(knex) {
  return knex.schema.alterTable('messages', function(table) {
    // Make receiver_id nullable to support group messages
    table.uuid('receiver_id').nullable().alter();
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = function(knex) {
  return knex.schema.alterTable('messages', function(table) {
    // Make receiver_id required again (but this might fail if there are null values)
    table.uuid('receiver_id').notNullable().alter();
  });
}; 