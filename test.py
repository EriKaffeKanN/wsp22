from math import floor

def fact(n):
     if n==0:
             return 1
     return n*fact(n-1)

def pow(x,n):
    pot = 1
    for i in range(n):
        pot *= x
    return pot

def lnn(n):
    if n ==1:
        return 0
    offset = n-1
    return ln(offset) + (
        (1/offset) -
        (1/(pow(offset, 2)*fact(2))) +
        (1/(pow(offset, 3)*fact(3))) -
        (1/(pow(offset, 4)*fact(4))) + 
        (1/(pow(offset, 5)*fact(5))) -
        (1/(pow(offset, 6)*fact(6))) +
        (1/(pow(offset, 7)*fact(7))) -
        (1/(pow(offset, 8)*fact(8))) +
        (1/(pow(offset, 9)*fact(9))) -
        (1/(pow(offset, 10)*fact(10))) +
        (1/(pow(offset, 11)*fact(11))) -
        (1/(pow(offset, 12)*fact(12))) +
        (1/(pow(offset, 13)*fact(13))) -
        (1/(pow(offset, 14)*fact(14))) +
        (1/(pow(offset, 15)*fact(15)))
    )


def ln(x):
    n = floor(x)
    constant = lnn(n)
    offset = n
    newX = x - n
    return constant + (
        (newX/offset) -
        (pow(newX, 2)/(pow(offset, 2)*fact(2))) +
        (pow(newX, 3)/(pow(offset, 3)*fact(3))) -
        (pow(newX, 4)/(pow(offset, 4)*fact(4))) + 
        (pow(newX, 5)/(pow(offset, 5)*fact(5))) -
        (pow(newX, 6)/(pow(offset, 6)*fact(6))) +
        (pow(newX, 7)/(pow(offset, 7)*fact(7))) -
        (pow(newX, 8)/(pow(offset, 8)*fact(8))) +
        (pow(newX, 9)/(pow(offset, 9)*fact(9))) -
        (pow(newX, 10)/(pow(offset, 10)*fact(10))) +
        (pow(newX, 11)/(pow(offset, 11)*fact(11))) -
        (pow(newX, 12)/(pow(offset, 12)*fact(12))) +
        (pow(newX, 13)/(pow(offset, 13)*fact(13))) -
        (pow(newX, 14)/(pow(offset, 14)*fact(14))) +
        (pow(newX, 15)/(pow(offset, 15)*fact(15)))
    )

def exp(x):
    return 1 + (
        x +
        pow(x,2)/fact(2) +
        pow(x,3)/fact(3) +
        pow(x,4)/fact(4) +
        pow(x,5)/fact(5) +
        pow(x,6)/fact(6) +
        pow(x,7)/fact(7) +
        pow(x,8)/fact(8) +
        pow(x,9)/fact(9) +
        pow(x,10)/fact(10) +
        pow(x,11)/fact(11) +
        pow(x,12)/fact(12) +
        pow(x,13)/fact(13)
    )

def coolPow(x,y):
    return exp(ln(x)*y)


print(coolPow(2.5, 2))