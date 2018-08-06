Goldsmiths MA Computational Art final project progress

Audiovisual installation using live tidal data from the River Thames to control motorised components and elements of field recordings made in Deptford, south east London.

Motorised components (one stepper motor and one peristaltic pump) are controlled via an Adafruit Motor Hat on a Raspberry Pi 3B+, with the Python scripts located in this repo.

The first Raspberry Pi sends the tidal information over osc to another Raspberry Pi which then uses the information to make audible changes to an ambient soundscape made up of the field recordings mentioned above, in addition to some realtime synthesis, written and composed in SuperCollider.
