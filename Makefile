
check:
	xmllint --noout --valid index.html
	xmllint --noout --valid codegen.html
	xmllint --noout --valid graph.html
	xmllint --noout --valid lpeg.html

graph:
	lua -l CodeGen.Graph -e "print(CodeGen.Graph.to_dot(CodeGen.Graph.template))" > graph.dot
	dot -T png -o graph.png graph.dot

clean:
	rm -f *.dot *.png
