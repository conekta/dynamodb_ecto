defmodule Dynamo.EctoTest do
  use Ecto.Integration.Case

  alias Ecto.Integration.TestRepo
  alias Ecto.Integration.Post
  alias Ecto.Integration.Tag
  alias Ecto.Integration.Order
  alias Ecto.Integration.Item

  import Ecto.Query, only: [from: 2]
  import Dynamo.Ecto.Helpers

  test "command/3" do
    assert %{"ok" => 1.0} == Dynamo.Ecto.command(TestRepo, ping: 1)
  end

  test "truncate/2" do
    TestRepo.insert!(%Post{})

    Dynamo.Ecto.truncate(TestRepo)
    assert [] == TestRepo.all(Post)
  end

  test "retrieve whole document" do
    TestRepo.insert!(%Tag{ints: [1, 2, 3]})

    query = from t in Tag, where: 1 in t.ints, select: fragment("ints.$": 1)
    assert [%{"ints" => [1]}] = TestRepo.all(query)
  end

  test "count" do
    TestRepo.insert!(%Post{visits: 1})

    query = from p in Post, where: p.visits == 1, select: count(p.id)
    assert 1 == TestRepo.one(query)
  end

  test "partial update in map" do
    post = TestRepo.insert!(%Post{meta: %{author: %{name: "michal"}, other: "value"}})
    TestRepo.update_all(Post, set: [meta: change_map("author.name", "michal")])

    assert TestRepo.get!(Post, post.id).meta ==
      %{"author" => %{"name" => "michal"}, "other" => "value"}

    order = Ecto.Changeset.change(%Order{}, item: %Item{price: 1})
    order = TestRepo.insert!(order)
    TestRepo.update_all(Order, set: [item: change_map("price", 10)])

    assert TestRepo.get!(Order, order.id).item.price == 10
  end

  test "partial update in array" do
    tag = Ecto.Changeset.change(%Tag{}, items: [%Item{price: 1}])
    tag = TestRepo.insert!(tag)
    TestRepo.update_all(Tag, set: [items: change_array(0, "price", 10)])

    [item] = TestRepo.get!(Tag, tag.id).items
    assert item.price == 10
  end

  test "decode empty map to map" do
    post = TestRepo.insert!(%Post{meta: %{}})
    assert post.meta == %{}

    post = TestRepo.get(Post, post.id)
    assert post.meta == %{}
  end

  test "list_collections does not include schema collection" do
    schema_collection = Ecto.Migration.SchemaMigration.__schema__(:source)

    refute schema_collection in Dynamo.Ecto.list_collections(TestRepo)
  end
end
