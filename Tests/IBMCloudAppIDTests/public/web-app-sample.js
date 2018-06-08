$(document).ready(function(){
	$(".hideOnStartup").hide();

	$.getJSON("/protected", function(data){
		console.log(data);
		$("#WhenAuthenticated").show();
		$("#sub").text(data.sub);
		$("#name").text(data.name || "Anonymous");
		$("#picture").attr("src", data.picture || "");
	}).fail(function(err){
		console.log(err);
		// Not authenticated yet
		$("#WhenNotAuthenticated").show();
	}).always(function(){
		$("#LoginButtons").show();
	});
});