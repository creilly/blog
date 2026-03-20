import numpy as np
from matplotlib import pyplot as plt

M = (
    (
        -1,  0, +1,  0
    ),(
         0, -1, +1, +2
    ),(
        +1,  0, -2,  0
    ),(
         0, +1,  0, -2
    )
)

vo = (1,0,0,0)

times = np.linspace(0,5,100)

eigvals, V = np.linalg.eig(M)

vt = np.einsum('ij,jt,jk,k->it',V,np.exp(np.outer(eigvals,times)),np.linalg.inv(V),vo)

for obs, label, ls, color in zip(
    (
        (1,0,0,0),                (0,0,1,0),                (0,1,0,0),                (0,0,0,1),                (0,0,1.25,0),                (0,0,1.25,2.5)
    ),(
        r'${}^{18}$O',            r'${}^{18}$O${}^{16}$O',  r'${}^{16}$O',            r'${}^{16}$O${}^{16}$O',  r'${}^{18}$O RAIRS',        r'${}^{16}$O RAIRS'
    ),(
        'dotted',                 'dashed',                 'dashdot',                (0,(3,5,1,5)),            'solid',                    'solid'
    ),(
        'black',                  'black',                  'black',                  'black',                  'blue',                     'red'
    )       
):
    plt.plot(times,np.dot(obs,vt),ls=ls,color=color,label=label)
plt.xlabel('time')
plt.ylabel('population')
plt.legend(loc='upper right')
plt.title(r'${}^{18}$O $\to$ ${}^{16}$O model')
plt.show()