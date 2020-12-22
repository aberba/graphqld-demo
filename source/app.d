import std;

import graphql;
import vibe.vibe;
import graphql.schema.directives;

struct User
{
	int id;
	string name;
}

interface Query {
	User[] users();
}

class Schema
{
	Query queryType;
	DefaultDirectives directives;
}

// Generate JSON data for 
// API response
Json fetchUsersJson() {
	// You may also construct your 
	// json data from the schema data types
	Json ret = Json.emptyArray();
	foreach(i; 0..5) {
		auto userJson = Json.emptyObject();
		userJson["id"] = i;
		userJson["name"] = "Jon " ~ i.to!string;

		ret ~= userJson;
	}

	return ret;
}

// For storing session informarion from
// headers, etc to be used in resolvers
// when doing conditional data fetching 
struct CustomContext {
	int userId;
}

GraphQLD!(Schema,CustomContext) graphqld;

void main()
{
	GQLDOptions opts;
	opts.asyncList = AsyncList.no;
	graphqld = new GraphQLD!(Schema,CustomContext)(opts);
	writeln(graphqld.schema);

	graphqld.setResolver("queryType", "users",
			delegate(string name, Json parent, Json args,
					ref CustomContext con) @trusted
			{
				Json ret = Json.emptyObject;
				ret["data"] = fetchUsersJson();
				return ret;
			}
		);


	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	listenHTTP(settings, &hello);

	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
	runApplication();
}

void hello(HTTPServerRequest req, HTTPServerResponse res)
{
	import graphql.validation.querybased;
	import graphql.validation.schemabased;

	// lex and parse query...comes in
	// a json format. To be used with Schema.
	Json j = req.json;
	string toParse = j["query"].get!string();
	Json vars = Json.emptyObject();

	auto l = Lexer(toParse);
	auto p = Parser(l);

	try {
		// No idea how this all works
		// still figuring out the API
		// from the source... WIP

		// It seems to parse and validate the 
		// schema document
		Document d = p.parseDocument();
		const(Document) cd = d;
		auto fv = new QueryValidator(d);
		fv.accept(cd);

	    noCylces(fv.fragmentChildren);
	    allFragmentsReached(fv);

	    // validate schema to ensure all requested fields
	    // really exist and matches the schema
		SchemaValidator!Schema sv = new SchemaValidator!Schema(d,
				graphqld.schema
			);
		sv.accept(cd);

		CustomContext con;
		// execute GraphQL query 
		Json gqld = graphqld.execute(d, vars, con);
		writeln(gqld.toPrettyString());

		// Send query response as JSON
		res.writeJsonBody(gqld);
		return;
	} catch(Throwable e) {
		// if there error, return error json
		// curretly spits a very verbose error message
		// you may need to return sensible error based on
		// your use case
		auto app = appender!string();
		while(e) {
			writeln(e.toString());
			app.put(e.toString());
			e = cast(Exception)e.next;
		}
		//writefln("\n\n\n\n#####\n%s\n#####\n\n\n\n", app.data);
		Json ret = Json.emptyObject;
		ret.insertError(app.data);
		res.writeJsonBody(ret);
		return;
	}
}
