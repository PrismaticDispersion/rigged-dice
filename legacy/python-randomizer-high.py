import random

numbers = [str(random.randint(7, 20)) for _ in range(20)]

print("numbers = [")
for n in numbers:
    print(f'    "{n}",')
print("];")
