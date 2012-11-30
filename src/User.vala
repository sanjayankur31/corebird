


class User{
	public static string screen_name;
	private static string avatar_name = "no_profile_pic.png";

	public static string get_avatar_path(){
		return "assets/user/"+avatar_name;
	}


	public static void load(){
		SQLHeavy.Query query = new SQLHeavy.Query(Corebird.db,
			"SELECT screen_name, avatar_name FROM `user`;");
		SQLHeavy.QueryResult res = query.execute();
		User.screen_name = res.fetch_string(0);
		User.avatar_name = res.fetch_string(1);
	}

	/**
	 * Updates the users's profile info.
	 *
	 * @param avatar_widget The widget to update if the avatar has changed.
	 */
	public static async void update_info(Gtk.Image avatar_widget) {

		var img_call = Twitter.proxy.new_call();
		img_call.set_function("1.1/users/show.json");
		img_call.set_method("GET");
		img_call.add_param("screen_name", User.screen_name);
		img_call.invoke_async.begin(null, (obj, res) => {
			img_call.invoke_async.end(res);
			string back = img_call.get_payload();
			var parser =new Json.Parser();
			parser.load_from_data(back);
			var root = parser.get_root().get_object();
			string url = root.get_string_member("profile_image_url");
			string avatar_name = Utils.get_file_name(url);
			// Check if the avatar of the user has changed.
			if (avatar_name != User.avatar_name
			    || !FileUtils.test(get_avatar_path(), FileTest.EXISTS)){
				File user_avatar = File.new_for_uri(url);
				// TODO: This is insanely inperformant and stupid. FIX!
				string dest_path = "assets/user/%s".printf(avatar_name);
				File dest = File.new_for_path(dest_path);
				user_avatar.copy(dest, FileCopyFlags.OVERWRITE); 

				Gdk.Pixbuf av = new Gdk.Pixbuf.from_file(dest_path);
				Gdk.Pixbuf scaled = new Gdk.Pixbuf(Gdk.Colorspace.RGB, true, 8, 24, 24);
				av.scale(scaled, 0, 0, 24, 24, 0, 0, 0.5, 0.5, Gdk.InterpType.HYPER);
				// Overwrite current avatar because its too big.
				string type = avatar_name.substring(avatar_name.last_index_of(".") + 1);
				scaled.save (dest_path, type);

				avatar_widget.set_from_file(dest_path);
				User.avatar_name = avatar_name;
				SQLHeavy.Query query = new SQLHeavy.Query(Corebird.db, 
					"UPDATE `user` SET `avatar_name`='%s';".printf(avatar_name));
				query.execute();
				message("Updated the avatar image!");
			}
		});
	}

}