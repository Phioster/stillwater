// Zeichnet ein Sprite flach in EINER Farbe und behaelt nur seinen Umriss.
//
// Gebraucht fuer den Schaumsaum am Schwimmer: dort soll die unterste
// sichtbare Pixelzeile die Farbe des Wasserrandes tragen, aber genau die Form
// haben, die der Schwimmer an dieser Zeile hat. Ein Sprite umfaerben geht mit
// modulate nicht -- das multipliziert, und der Saum bliebe rot.
shader_type canvas_item;

uniform vec4 saum : source_color = vec4(1.0);

void fragment() {
	COLOR = vec4(saum.rgb, texture(TEXTURE, UV).a * saum.a);
}
