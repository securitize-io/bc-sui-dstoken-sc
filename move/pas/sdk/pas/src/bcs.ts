import { bcs, BcsType } from '@mysten/sui/bcs';

import { MoveStruct } from './contracts/utils/index.js';

/** An entry in the map */
export function Entry<K extends BcsType<any>, V extends BcsType<any>>(...typeParameters: [K, V]) {
	return new MoveStruct({
		name: `0x2::vec_map::Entry<${typeParameters[0].name as K['name']}, ${typeParameters[1].name as V['name']}>`,
		fields: {
			key: typeParameters[0],
			value: typeParameters[1],
		},
	});
}
/* VecMap representation */
export function VecMap<K extends BcsType<any>, V extends BcsType<any>>(...typeParameters: [K, V]) {
	return new MoveStruct({
		name: `0x2::vec_map::VecMap<${typeParameters[0].name as K['name']}, ${typeParameters[1].name as V['name']}>`,
		fields: {
			contents: bcs.vector(Entry(typeParameters[0], typeParameters[1])),
		},
	});
}

/** dynamic Field representation */
export function Field<Name extends BcsType<any>, Value extends BcsType<any>>(
	...typeParameters: [Name, Value]
) {
	return new MoveStruct({
		name: `0x2::dynamic_field::Field<${typeParameters[0].name as Name['name']}, ${typeParameters[1].name as Value['name']}>`,
		fields: {
			/**
			 * Determined by the hash of the object ID, the field name value and it's type,
			 * i.e. hash(parent.id || name || Name)
			 */
			id: bcs.Address,
			/** The value for the name of this field */
			name: typeParameters[0],
			/** The value bound to this field */
			value: typeParameters[1],
		},
	});
}
