import 'post.dart';

class PostPage {
  final List<Post> posts;
  final String? nextCursor;
  final bool hasMore;

  const PostPage({required this.posts, required this.hasMore, this.nextCursor});
}
