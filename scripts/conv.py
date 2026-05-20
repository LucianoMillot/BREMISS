from dipy.io.stateful_tractogram import Space, StatefulTractogram
from dipy.io.streamline import save_tractogram

# Reprends ton objet 'streamlines' du script précédent
sft = StatefulTractogram(streamlines, img, Space.RASMM)

# On change juste l'extension en .tck
save_tractogram(sft, os.path.join(path, 'tractography_csd.tck'))
print("Conversion en .tck terminée.")