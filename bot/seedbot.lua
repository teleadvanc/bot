۱package.path = package.path .. ۲';.luarocks/share/lua/5.2/?.lua'
۳  ..';.luarocks/share/lua/5.2/?/init.lua'
۴package.cpath = package.cpath .. ۵';.luarocks/lib/lua/5.2/?.so'

۶require("./bot/utils")

۷VERSION = '2'

۸-- This function is called when tg receive a msg
۹function on_msg_receive (msg)
 ۱۰ if not started then
    ۱۱return
 ۱۲ end

 ۱۳ local receiver = get_receiver(msg)
  ۱۴print (receiver)

 ۱۵ --vardump(msg)
 ۱۶ msg = pre_process_service_msg(msg)
 ۱۷ if msg_valid(msg) then
   ۱۸ msg = pre_process_msg(msg)
  ۱۹  if msg then
    ۲۰  match_plugins(msg)
    ۲۱  if redis:get("bot:markread") then
      ۲۲  if redis:get("bot:markread") == "on" then
        ۲۳  mark_read(receiver, ok_cb, false)
       ۲۴ end
    ۲۵  end
    end
  ۲۶end
۲۷end

۲۸function ok_cb(extra, success, result)
۲۹end

۳۰function on_binlog_replay_end()
 ۳۱ started = true
 ۳۲ postpone (cron_plugins, false, 60*5.0)

  ۳۳_config = load_config()

  ۳۴-- load plugins
 ۳۵ plugins = {}
  load_plugins()
۳۷end

function msg_valid(msg)
  -- Don't process outgoing messages
 ۴۰ if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
 ۴۳ end

  ۴۴-- Before bot was started
  ۴۵if msg.date < now then
   ۴۶ print('\27[36mNot valid: old msg\27[39m')
   ۴۷ return false
  ۴۸end

  ۴۹if msg.unread == 0 then
  ۵۰  print('\27[36mNot valid: readed\27[39m')
   ۵۱ return false
  ۵۲end

 ۵۳ if not msg.to.id then
  ۵۴  print('\27[36mNot valid: To id not provided\27[39m')
  ۵۵  return false
  ۵۶end

  ۵۷if not msg.from.id then
   ۵۸ print('\27[36mNot valid: From id not ۵۹provided\27[39m')
  ۶۰  return false
  ۶۱end

۶۲  if msg.from.id == our_id then
  ۶۳  print('\27[36mNot valid: Msg from our id\27[39m')
 ۶۴   return false
 ۶۵ end

 ۶۶ if msg.to.type == 'encr_chat' then
  ۶۷  print('\27[36mNot valid: Encrypted chat\27[39m')
   ۶۸ return false
 ۶۹ end

 ۷۰ if msg.from.id == 777000 then
  	۷۱local login_group_id = 1
  	۷۲--It will send login codes to this chat
   ۷۳ send_large_msg('chat#id'..login_group_id, msg.text)
 ۷۴ end

  ۷۵return true
۷۶end

--
۷۸function pre_process_service_msg(msg)
  ۷۹ if msg.service then
     ۸۰ local action = msg.action or {type=""}
     ۸۱ -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

   ۸۳   -- wipe the data to allow the bot to read service messages
      ۸۵if msg.out then
        ۸۶ msg.out = false
   ۸۷   end
    ۸۸  if msg.from.id == our_id then
       ۹۰  msg.from.id = 0
     ۹۰ end
  ۹۱ end
 ۹۲  return msg
end

-- Apply plugin.pre_process function
۹۴function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
۹۶    if plugin.pre_process and msg then
    ۹۷  print('Preprocess', name)
     ۹۸ msg = plugin.pre_process(msg)
  ۹۹  end
 ۱۰۰ end

  ۱۰۰۱return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat ۱۰۹table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
 ۱۱۲ local disabled_chats = _config.disabled_plugin_on_chat
  ۱۱۳-- Table exists and chat has disabled plugins
 ۱۱۴ if disabled_chats and disabled_chats[receiver] then
  ۱۱۵  -- Checks if plugin is disabled on this chat
    ۱۱۶for disabled_plugin,disabled in ۱۱۷pairs(disabled_chats[receiver]) do
     ۱۱۸ if disabled_plugin == plugin_name and disabled then
        ۱۱۹local warning = 'Plugin '..disabled_plugin..' is ۱۲۰disabled on this chat'
      ۱۲۱  print(warning)
       ۱۲۲ send_msg(receiver, warning, ok_cb, false)
      ۱۲۳  return true
     ۱۲۴ end
  ۱۲۵  end
 ۱۲۶ end
 ۱۲۷ return false
end

function match_plugin(plugin, plugin_name, msg)
  ۱۳۰local receiver = get_receiver(msg)

 ۱۳۱ -- Go over patterns. If one matches it's enough.
 ۱۳۲ for k, pattern in pairs(plugin.patterns) do
   ۱۳۳ local matches = match_pattern(pattern, msg.text)
   ۱۳۴ if matches then
    ۱۳۵  print("msg matches: ", pattern)

     ۱۳۶ if is_plugin_disabled_on_chat(plugin_name, receiver) then
 ۱۳۷       return nil
     ۱۳۷ end
    ۱۳۸  -- Function exists
    ۱۳۹  if plugin.run then
      ۱۴۰  -- If plugin is for privileged users only
       ۱۴۱ if not warns_user_not_allowed(plugin, msg) then
         ۱۴۲ local result = plugin.run(msg, matches)
        ۱۴۳  if result then
         ۱۴۴   send_large_msg(receiver, result)
         ۱۴۵ end
       ۱۴۶ end
     ۱۴۷ end
     ۱۴۸ -- One patterns matches
    ۱۴۹  return
   ۱۵۰ end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
 ۱۵۵ send_large_msg(destination, text)
end

۱۵۶-- Save the content of _config to config.lua
f۱۵۷unction save_config( )
 ۱۵۸ serialize_to_file(_config, './data/config.lua')
 ۱۵۹ print ('saved config into ./data/config.lua')
۱۶۰end

۱۶۱-- Returns the config from config.lua file.
-۱۶۲- If file doesn't exist, create it.
function load_config( )
۱۶۴  local f = io.open('./data/config.lua', "r")
  ۶۵-- If config.lua doesn't exist
  ۶۶if not f then
   ۶۷ print ("Created new config file: data/config.lua")
  ۶۸  create_config()
  ۶۹else
   ۷۰ f:close()
  ۷۱end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
 ۷۵ end
 ۷۶ return config
end

-- ۷۸Create a basic config.json file and saves it.
function create_config( )
  -- A۸۰ simple config with basic plugins and ourselves as privileged user
  co۸۲nfig = {
    en۸۳abled_plugins = {
    "onser۸۴vice",
    "inre۸۵alm",
    "ingro۸۶up",
    "inpm",
    "ba۸۸nhammer",
    "stats",
    "anti_۹۰spam",
    "owne۹۱rs",
    "ara۹۲bic_lock",
    "s۹۳et",
    "g۹۴et",
    "b۹۵roadcast",
    "download۹۶_media",
    "inv۹۷ite",
    "a۹۸ll",
    "lea۹۹ve_ban",
  ۱۰۰  "admin"
 ۱   },
 ۲   sudo_users = ۳{110626080,103649648,143723991,111020322,0,tonumber(170958132},--Sudo users
  ۵  disabled_channels = {},
 ۶   moderation = {data = 'data/moderation.json'},
 ۷   about_text = [[Teleseed v2 - Open Source
۸An advance Administration bot based on yagop/telegram-bot 

۹https://github.com/SEEDTEAM/TeleSeed

۱۰Our team!
A۱۱lphonse (@Iwals)
I M /-۱۲\ N (@Imandaneshi)
Siyanew (۱۳@Siyanew)
Rondoozl۱۴e (@Potus)
Seyed۱۵an (@Seyedan25)

Special than۱۶ks to:
Juan Pot۱۷ato
S۱۸iyanew
To۱۹pkecleon
V۲۰amptacus

O۱ur channels:
En۲glish: @TeleSeedCH
P۳ersian: @IranSeed
۴]],
    ۵help_text_realm = [[
۶Realm Commands:

۷!creategroup [name]
C۸reate a group

!createrealm [name]
Create a realm

!setname [name]
Set realm name

!setabout [group_id] [text]
Set a group's about text

!setrules [grupo_id] [text]
Set a group's rules

!lock [grupo_id] [setting]
Lock a group's setting

!unlock [grupo_id] [setting]
Unock a group's setting

!wholist
Get a list of members in group/realm

!who
Get a file of members in group/realm

!type
Get group type

!kill chat [grupo_id]
Kick all memebers and delete group

!kill realm [realm_id]
Kick all members and delete realm

!addadmin [id|username]
Promote an admin by id OR username *Sudo only

!removeadmin [id|username]
Demote an admin by id OR username *Sudo only

!list groups
Get a list of all groups

!list realms
Get a list of all realms

!log
Get a logfile of current group or realm

!broadcast [text]
!broadcast Hello !
Send text to all groups
» Only sudo users can run this command

!bc [group_id] [text]
!bc 123456789 Hello !
This command will send text to [group_id]

» U can use both "/" and "!" 

» Only mods, owner and admin can add bots in group

» Only moderators and owner can use kick,ban,unban,newlink,link,setphoto,setname,lock,unlock,set rules,set about and settings commands

» Only owner can use res,setowner,promote,demote and log commands

]],
    help_text = [[
Commands list :

!kick [username|id]
You can also do it by reply

!ban [ username|id]
You can also do it by reply

!unban [id]
You can also do it by reply

!who
Members list

!modlist
Moderators list

!promote [username]
Promote someone

!demote [username]
Demote someone

!kickme
Will kick user

!about
Group description

!setphoto
Set and locks group photo

!setname [name]
Set group name

!rules
Group rules

!id
Return group id or user id

!help
Get commands list

!lock [member|name|bots|leave] 
Locks [member|name|bots|leaveing] 

!unlock [member|name|bots|leave]
Unlocks [member|name|bots|leaving]

!set rules [text]
Set [text] as rules

!set about [text]
Set [text] as about

!settings
Returns group settings

!newlink
Create/revoke your group link

!link
Returns group link

!owner
Returns group owner id

!setowner [id]
Will set id as owner

!setflood [value]
Set [value] as flood sensitivity

!stats
Simple message statistics

!save [value] [text]
Save [text] as [value]

!get [value]
Returns text of [value]

!clean [modlist|rules|about]
Will clear [modlist|rules|about] and set it to nil

!res [username]
Returns user id

!log
Will return group logs

!banlist
Will return group ban list

» U can use both "/" and "!" 

» Only mods, owner and admin can add bots in group

» Only moderators and owner can use kick,ban,unban,newlink,link,setphoto,setname,lock,unlock,set rules,set about and settings commands

» Only owner can use res,setowner,promote,demote and log commands

]]
  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
