extends Node

const MAX_STARS: float = 5.0
const STARTING_RATING: float = 3.2

var average_rating: float = STARTING_RATING
var review_count: int = 0
var recent_reviews: Array[Dictionary] = []


func _ready() -> void:
	reset_to_defaults()


func reset_to_defaults() -> void:
	average_rating = STARTING_RATING
	review_count = 0
	recent_reviews.clear()


func add_review(rating: float, guest_name: String, comment: String) -> void:
	var clamped_rating: float = clampf(rating, 1.0, MAX_STARS)
	review_count += 1
	average_rating = ((average_rating * float(review_count - 1)) + clamped_rating) / float(review_count)
	var review := {
		"rating": clamped_rating,
		"guest_name": guest_name,
		"comment": comment,
	}
	recent_reviews.append(review)
	if recent_reviews.size() > 8:
		recent_reviews.pop_front()
	EventBus.reputation_changed.emit()


func get_spawn_interval() -> float:
	var bonus: float = (average_rating - 3.0) * 1.2
	return clampf(14.0 - bonus, 6.0, 18.0)


func export_save_data() -> Dictionary:
	return {
		"average_rating": average_rating,
		"review_count": review_count,
		"recent_reviews": recent_reviews.duplicate(true),
	}


func import_save_data(data: Dictionary) -> void:
	average_rating = data.get("average_rating", STARTING_RATING)
	review_count = data.get("review_count", 0)
	recent_reviews.clear()
	for entry: Dictionary in data.get("recent_reviews", []):
		recent_reviews.append(entry)
	EventBus.reputation_changed.emit()
