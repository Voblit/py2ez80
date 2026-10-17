import math
import random

class Particle:
    pass

def calculate_distance(x, y):
    return math.sqrt(x * x + y * y)

print("--- Py2eZ80 Engine ---")

random.seed(42)

scores = [100, 250, 500]
player_name = "Hero"
energy = 100.0

crit_chance = random.random()
bonus_damage = random.randint(15, 50)
print("Random Crit Chance:")
print(crit_chance)
print("Random Bonus Damage:")
print(bonus_damage)

for i in range(0, 3):
    energy -= 10.5
    scores.append(i * 50 + random.randint(1, 10))

dist = calculate_distance(30, 40)
print("Calculated Distance:")
print(dist)

try:
    if energy < 0:
        raise 1
    print("Energy Normal!")
except:
    print("Energy Depleted!")
finally:
    print("Execution complete.")
