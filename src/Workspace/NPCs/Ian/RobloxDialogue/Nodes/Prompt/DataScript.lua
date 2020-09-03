--this data script returns arbitrary data for this node, you can use it to
--pass whatever useful information you may need to both the client and
--the dynamic text functions that it may or may not be involved with
--it should follow the format
--return {
--    someKey = someValue,
--    anotherKey = anotherValue,
--}
--and so on. Be careful to remember that any functions, code, etc. cannot
--be passed from server to client. Only strings, ints, tables, etc. will
--be preserved, and besides, this isn't the place to store code! Use
--actions and conditions to perform code instead
return {
	
}