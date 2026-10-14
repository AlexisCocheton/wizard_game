shader_type canvas_item;
// CONTOUR NOIR DU SCEAU D ELEMENT (vague 10, demande du co-auteur : « rajoute un
// petit contour noir autour de l element de la carte »).
//
// Le contour d origine est DANS le PNG (un trait brun fin, perdu a 40 px sur le
// papier teinte d une carte). Celui-ci est trace a l affichage, a la meme
// epaisseur RELATIVE quelle que soit la taille du sceau : la forme du cadre, qui
// porte l element pour un joueur daltonien, se detache nettement du dessin.
//
// Les logos touchent les bords de leur case : le dessin est donc REDUIT dans la
// case, et le contour remplit la marge. CardView.with_type_badge agrandit la case
// d autant, le logo garde sa taille a l ecran.

// Epaisseur du contour, en part du cote du LOGO (pas de la case).
uniform float epaisseur : hint_range(0.0, 0.3) = 0.07;
uniform vec4 couleur : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// La teinte du noeud (modulate du gris des cartes a obtenir) : COLOR du vertex,
// gardee a part parce que le fragment recompose la couleur lui-meme.
varying vec4 teinte;

void vertex() {
	teinte = COLOR;
}

void fragment() {
	float marge = epaisseur / (1.0 + 2.0 * epaisseur);
	float echelle = 1.0 - 2.0 * marge;
	vec2 uv = (UV - vec2(marge)) / echelle;
	vec4 dessin = vec4(0.0);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		dessin = texture(TEXTURE, uv);
	}
	// Dilatation de la silhouette : le plus opaque des voisins sur deux cercles
	// (pleine epaisseur et demi-epaisseur), seize directions chacun.
	float a = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = 6.2831853 * float(i) / 16.0;
		vec2 d = vec2(cos(ang), sin(ang)) * epaisseur;
		vec2 p1 = uv + d;
		vec2 p2 = uv + d * 0.5;
		if (p1.x >= 0.0 && p1.y >= 0.0 && p1.x <= 1.0 && p1.y <= 1.0) {
			a = max(a, texture(TEXTURE, p1).a);
		}
		if (p2.x >= 0.0 && p2.y >= 0.0 && p2.x <= 1.0 && p2.y <= 1.0) {
			a = max(a, texture(TEXTURE, p2).a);
		}
	}
	// Bord NET : la silhouette dilatee est seuillee, pas fondue.
	a = smoothstep(0.2, 0.55, a) * couleur.a;
	vec4 c;
	c.rgb = mix(couleur.rgb, dessin.rgb, dessin.a);
	c.a = dessin.a + a * (1.0 - dessin.a);
	COLOR = c * teinte;
}
