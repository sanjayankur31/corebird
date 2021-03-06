/*  This file is part of corebird, a Gtk+ linux Twitter client.
 *  Copyright (C) 2013 Timm Bäder
 *
 *  corebird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  corebird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with corebird.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

class MentionsTimeline : IMessageReceiver, DefaultTimeline {

  public MentionsTimeline(int id){
    base (id);
  }

  private void stream_message_received (StreamMessageType type, Json.Node root_node){ // {{{
    Json.Object root = root_node.get_object ();

    if (type == StreamMessageType.TWEET) {
      var author = root.get_object_member ("user");
      if (author.get_int_member ("id") == account.id &&
          !root.get_null_member ("in_reply_to_status_id")) {
        mark_seen (root.get_int_member ("in_reply_to_status_id"));
        return;
      }


      if (root.get_string_member("text").contains("@"+account.screen_name)) {
        GLib.DateTime now = new GLib.DateTime.now_local ();
        Tweet t = new Tweet();
        t.load_from_json(root_node, now);
        if (t.user_id == account.id)
          return;

        // If the tweet is a tweet the user retweeted, check
        // if it's already in the list. If so, mark it retweeted
        if (t.retweeted_by == account.name) {
          tweet_list.foreach ((w) => {
            if (w == null || !(w is TweetListEntry))
              return;

            var tle = (TweetListEntry) w;
            if (tle.tweet.id == t.rt_id) {
              tle.tweet.retweeted = true;
            }
          });
          return;
        }

        bool auto_scroll = Settings.auto_scroll_on_new_tweets ();

        this.balance_next_upper_change (TOP);
        var entry = new TweetListEntry(t, main_window, account);
        entry.seen = false;

        delta_updater.add (entry);
        tweet_list.add (entry);
        if (this.scrolled_up && (t.user_id == account.id || auto_scroll)) {
          this.scroll_up_next (true, false,
                               main_window.cur_page_id != this.id);
        }



        unread_count++;
        update_unread_count();
        this.max_id =  t.id;

        if (Settings.notify_new_mentions ()) {
          NotificationManager.notify_pixbuf(
            "New Mention from @"+t.screen_name,
            t.text,
            t.avatar);
        }
      }
    }
  } // }}}

  private void mark_seen (int64 id) {
    // TODO: All these foreach loops don't allow for early exit.
    tweet_list.@foreach ((w) => {
      if (w == null || !(w is TweetListEntry))
        return;
      var tle = (TweetListEntry) w;
      if (tle.tweet.id == id) {
        tle.seen = true;
        unread_count--;
        update_unread_count ();
      }
    });
  }

  public override void load_newest () {
    this.loading = true;
    this.load_newest_internal.begin("1.1/statuses/mentions_timeline.json", Tweet.TYPE_MENTION, () => {
      this.loading = false;
    });
  }

  public override void load_older () {
    if (!initialized)
      return;

    this.balance_next_upper_change (BOTTOM);
    main_window.start_progress ();
    this.loading = true;
    this.load_older_internal.begin ("1.1/statuses/mentions_timeline.json", Tweet.TYPE_MENTION, () => {
      this.loading = false;
      main_window.stop_progress ();
    });
  }



  public override void create_tool_button (RadioToolButton? group) {
    tool_button = new BadgeRadioToolButton(group, "corebird-mentions-symbolic");
    tool_button.label = "Mentions";
  }

}
