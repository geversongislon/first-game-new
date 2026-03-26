class_name AttackBehavior
extends Resource

## Base class for all attack behaviors.
## Assign a subclass (MeleeSwing, MeleePounce, RangedProjectile, …) to the
## enemy's attack_behavior export field to give it that attack type.
## Each subclass only exposes parameters relevant to its own attack.

## Runs every physics frame BEFORE move_and_slide.
## Use this for state machines that need per-frame updates (e.g. pounce).
func tick(enemy: CharacterBody2D, delta: float) -> void:
	pass

## Called by the enemy base when attack_phase == READY and a player is nearby.
## The behavior decides whether and how to initiate the attack.
func try_attack(enemy: CharacterBody2D) -> void:
	pass

## Return true while the behavior needs to suppress normal movement
## (e.g. during pounce windup/airborne/recoil).
func blocks_movement() -> bool:
	return false

## Called when the enemy dies or is stunned — reset internal state.
func reset() -> void:
	pass
