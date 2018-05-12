class Event < ActiveRecord::Migration[5.2]
  def change
    create_table :events do |t|
      t.string :discourse_topic_id
      t.jsonb :discourse_json_data

      t.datetime :discourse_updated_at
      t.datetime :meetup_at

      t.string :meetup_event_id
      t.string :meetup_urlname
      t.jsonb :meetup_json_data

      t.timestamps
    end
  end
end
