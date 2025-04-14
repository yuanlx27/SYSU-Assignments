def BinarySearch(nums, target):
    li, ri = 0, len(nums) - 1
    while li <= ri:
        mi = (li + ri) // 2
        if nums[mi] == target:
            return mi

        if nums[mi] < target:
            li = mi + 1
        else:
            ri = mi - 1

    return -1

print(BinarySearch([ 1, 3, 5, 7, 9 ], 7))
