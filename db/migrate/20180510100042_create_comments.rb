class CreateComments < ActiveRecord::Migration[5.2]
  def change
    create_table :comments do |t|
      t.integer :event_id

      t.integer :discourse_comment_id
      t.integer :discourse_post_number
      t.integer :discourse_reply_to_post_number
      t.jsonb :discourse_json_data

      t.timestamp :meetup_created_at
      t.integer :meetup_comment_id
      t.integer :meetup_in_reply_to
      t.jsonb :meetup_json_data

      t.timestamps
    end
  end
end
