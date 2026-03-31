String greetingFor(String name) {
  final greeter = Greeter('Hello, {name}!');
  return greeter.greet(name);
}

void main() {
  print(greetingFor('world'));
}
