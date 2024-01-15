import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef JSON = Map<String, dynamic>;

class Cat {

   static const version = 1;

   String name;
   List<String> items;
   Cat(this.name, this.items);

   JSON toJson() => {
      "version": version,
      "name": name,
      "items": items,
   };

   factory Cat.fromJson(JSON json) => switch (json["version"]) {
      _ => Cat.fromJsonV1(json),
   };

   factory Cat.fromJsonV1(JSON json) =>
      Cat(
         json["name"],
         (json["items"] as List).cast<String>().toList()
      );

}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToDo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

   List<Cat> cats = [];

   @override
   void initState() {
     super.initState();
     SharedPreferences.getInstance()
      .then((p) {
         if (mounted) {
            setState(() {
               var data = jsonDecode(p.getString("data") ?? jsonEncode(cats)) as List;
               cats = data.map((el) => Cat.fromJson(el)).toList();
               save();
            });
         }
      });
   }

   void save() async {
      var sp = await SharedPreferences.getInstance();
      sp.setString("data", jsonEncode(cats));
   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         backgroundColor: Theme.of(context).colorScheme.primary,
         actions: [
            IconButton(
               color: Theme.of(context).colorScheme.onPrimary,
               icon: const Icon(Icons.bookmark_add),
               onPressed: () => askAddItem(true),
            )
         ],
        title: const Text("Todo List"),
      ),
      body: TodoListView(
        cats: cats,
        didMutate: () {
          setState(() {});
          save();
        },
        onAdd: (cat) {
          askAddItem(false, cat);
        },
        onEdit: (cat) {
          // TODO
        },
        onEditItem: (cat, item) {
          askEditItem(cat, item);
        },
        rearrange: false,
      ),
      floatingActionButton: FloatingActionButton(
         child: const Icon(Icons.add),
         onPressed: () => askAddItem(false)
      ),
    );
  }

  void askEditItem(Cat cat, String item) async {
   var input = TextEditingController(text: item);
   showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState2) {
          return Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                children: [
                 const Text("Edit item", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
                 const SizedBox(height: 8,),
                 TextField(
                    textAlign: TextAlign.center,
                    autofocus: true,
                    controller: input,
                    maxLines: 1,
                    onEditingComplete: () {
                       var newItem = input.text.trim();
                       if (newItem.isEmpty) {
                          setState2((){
                             input.text = newItem;
                          });
                          return;
                       }
                       var i = cat.items.indexOf(item);
                       item = newItem;
                       cat.items[i] = item;
                       setState((){});
                       setState2((){});
                    },
                 ),
                 const SizedBox(height: 8,),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [

                     for (var c in cats)
                     ChoiceChip(
                        label: Text(c.name),
                        selected: c == cat,
                        onSelected: (val) {
                           if (val) {
                             cat.items.remove(item);
                             c.items.add(item);
                             cat = c;
                             setState2(() {});
                             setState(() {});
                           }
                        },
                     )
                  ]),
                ],
              ),
            ),
          );
        }
      ));
  }

   void askAddItem(bool isCat, [Cat? cat]) {
      var input = TextEditingController();
      if (cats.isEmpty) {
         setState(() {
            cats.add(Cat("Todo", []));
         });
      }
      var selectedCat = cat ?? cats.first;
      showDialog(
         context: context,
         builder: (context) => StatefulBuilder(
           builder: (context, setState2) {
            void submit(String item) {
               item = item.trim();
               if (item.isEmpty) return;
               setState(() {
                  if (!isCat) {
                     selectedCat.items.add(item);
                  } else {
                     cats.add(Cat(item, []));
                  }
                  Navigator.pop(context);
                  save();
               });
            }
             return Material(
               child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     TextField(
                        textAlign: TextAlign.center,
                        autofocus: true,
                        controller: input,
                        maxLines: 1,
                        onSubmitted: submit,
                     ),
                     const SizedBox(height: 12,),
                     if (!isCat)
                     Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                           for (var cat in cats)
                           ChoiceChip(
                             label: Text(cat.name),
                             selected: cat == selectedCat,
                             onSelected: (sel) {
                                if (sel) {
                                   setState2(() {
                                      selectedCat = cat;
                                   });
                                }
                             },
                          ),
                        ],
                     ),
                     const SizedBox(height: 12,),
                     ElevatedButton(
                        child: const Text("OK"),
                        onPressed: () => submit(input.text),
                     )
                  ],
               ),
             );
           }
         )
      );
   }

}

void reorder(List l, int i, int j) {
   if (j > i) j--;
   l.insert(j, l.removeAt(i));
}

class TodoListView extends StatelessWidget {

   final List<Cat> cats;
   final VoidCallback didMutate;
   final bool rearrange;

   final void Function(Cat) onEdit, onAdd;
   final void Function(Cat, String) onEditItem;

  const TodoListView({super.key, required this.cats, required this.didMutate, required this.rearrange, required this.onEdit, required this.onAdd, required this.onEditItem});

  @override
   Widget build(BuildContext context) {
      if (rearrange) {
        return ReorderableListView(
          children: cats.map(header).toList(),
          onReorder: (i, j) {

          }
        );
      }
      return ListView(
       children: [
          for (var cat in cats) ...[
            header(cat),
            for (var item in cat.items)
            ItemTile(
              item: item,
              onEdit: () {
                onEditItem(cat, item);
              },
              onDelete: () {
                cat.items.remove(item);
                didMutate();
              },
            ),
          ]
       ],
    );
   }

   Widget header(Cat cat) =>
      Slidable(
        key: ObjectKey(cat),
         endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
               SlidableAction(
                  icon: Icons.delete,
                  backgroundColor: Colors.red,
                  label: "Delete",
                  onPressed: (context) {},
               ),
              SlidableAction(
                backgroundColor: Colors.blue,
                icon: Icons.edit,
                onPressed: (context) => onEdit(cat)
              ),
            ],
         ),
         child: ListTile(
            title: Row(
               children: [
                  Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(" (${cat.items.length})"),
               ],
            ),
            trailing: IconButton(
               icon: const Icon(Icons.add),
               onPressed: () {
                  onAdd(cat);
               },
            ),
            onTap: () {},
         ),
      );
}

class ItemTile extends StatelessWidget {

  final String item;
  final VoidCallback onEdit, onDelete;

  const ItemTile({super.key, required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) =>
    Slidable(
      key: ValueKey(item),
      startActionPane: ActionPane(
         motion: const DrawerMotion(),
         children: [
            SlidableAction(
               backgroundColor: Colors.red,
               icon: Icons.delete,
               onPressed: (context) => onDelete(),
            ),
            SlidableAction(
               backgroundColor: Colors.blue,
               icon: Icons.edit,
               onPressed: (context) => onEdit()
            ),
         ],
      ),
      child: ListTile(
         title: Text(item)
      )
   );
}
