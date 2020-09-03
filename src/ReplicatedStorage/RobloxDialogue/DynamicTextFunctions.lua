--this is a table of named functions that replace text dynamically in prompt or response contents
--whenever the dialogue system encounters a text like <SomeNameHere>, it will replace that text
--with a function from this table with the same name (SomeNameHere). So, for example, if you have
--a prompt that says "Hello, <PlayerName>! How is your family?" The dialogue system would automatically
--detect the <PlayerName>, call the function PlayerName below, and replace the text with whatever
--the function returns. So, if Telamon was speaking to this NPC, the text would read
--"Hello, Telamon! How is your family?"

--the player is the player talking to the npc
--the dialogueFolder is the folder in the Roblox object hierarchy that represents this conversation
--the node is the node that is calling this function

return {
	PlayerName = function(player, dialogueFolder, node)
		return player.Name
	end,
}