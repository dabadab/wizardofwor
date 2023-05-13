wow.bin: wizard_of_wor.asm inc.sprites_misc.asm inc.sprites_monsters2.asm inc.sprites_monsters1.asm inc.sprites_player.asm
	64tass -a wizard_of_wor.asm -b -o wow.bin

wow.crt: wow.bin
	cartconv -i wow.bin -o wow.crt -t normal

bin: wow.bin

crt: wow.crt

clean:
	rm -f *.bin *.crt
