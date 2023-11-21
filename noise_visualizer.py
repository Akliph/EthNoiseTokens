import random

import pygame.locals

pygame.init()

seed = 123

WIDTH = 600
HEIGHT = 600

Xmin = 20
Ymin = 20
Xmax = 100
Ymax = 100

area = abs(Xmax - Xmin) * abs(Ymax - Ymin)
print(f"This region is {area} gwei or ${area*0.0338}")

def checkCollision(a, b):
    if ((a[0] >= b[0] and a[0] <= b[2]) and
        (a[1] >= b[1] and a[1] <= b[3])): return True;

    if ((a[2] >= b[0] and a[2] <= b[2]) and
        (a[3] >= b[1] and a[3] <= b[3])): return True;

    return False

screen = pygame.display.set_mode((WIDTH, HEIGHT))

running = True

for x in range(WIDTH):
    for y in range(HEIGHT):
        color = ((x * seed) - (y * seed) + (x + y) * (x * y)) % 255
        screen.set_at((x, y), (color, color, color))

while running:
    # seed = pygame.mouse.get_pos()[0] + pygame.mouse.get_pos()[0]
    for x in range(WIDTH):
        for y in range(HEIGHT):
            color = ((x * seed) - (y * seed) + (x + y) * (x * y)) % 255
            screen.set_at((x, y), (color, color, color))

    pygame.draw.rect(screen, (255, 0, 0), (Xmin, Ymin, Xmax, Ymax), 3)

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
    k = pygame.key.get_pressed()
    if k[pygame.K_RIGHT]:
        seed += 1

    pygame.display.flip()
