export enum AttributeType {
    NONE = 0,
    KYC_APPROVED = 1,
    ACCREDITED = 2,
    QUALIFIED = 4,
    PROFESSIONAL = 8,
}

export enum AttributeStatus {
    PENDING = 0,
    APPROVED = 1,
    REJECTED = 2,
}

export interface Attribute {
    name: AttributeType
    status: AttributeStatus
    expiry: number
}

export function toAttributeType(type: string): AttributeType {
    const map: any = {
        "0": AttributeType.NONE,
        "1": AttributeType.KYC_APPROVED,
        "2": AttributeType.ACCREDITED,
        "4": AttributeType.QUALIFIED,
        "8": AttributeType.PROFESSIONAL,
    }

    if (type === "0") {
        return AttributeType.NONE
    }

    if (!map[type]) {
        throw `Attribute type ${type} does not exist`
    }

    return map[type]
}

export function toAttributeStatus(status: string): AttributeStatus {
    const map: any = {
        "0": AttributeStatus.PENDING,
        "1": AttributeStatus.APPROVED,
        "2": AttributeStatus.REJECTED,
    }

    if (status === "0") {
        return AttributeStatus.PENDING
    }

    if (!map[status]) {
        throw `Attribute status ${status} does not exist`
    }

    return map[status]
}