export type Fill = { above: boolean?, below: boolean? }

export type Region = { vector }

export type Segment = {
	start: vector,
	finish: vector,

	my_fill_above: boolean,
	my_fill_below: boolean,

	other_filled: boolean,
	other_filled_above: boolean?,
	other_filled_below: boolean?,
}

export type Polygon = { regions: { Region }, inverted: boolean }

export type CombinedSegments = { combined: { Segment }, inverted1: boolean, inverted2: boolean }
export type Segments = { segments: { Segment }, inverted: boolean }

return {}
