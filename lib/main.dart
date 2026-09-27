const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('تحويل رصيد')),
                      selected: isAddingDebt,
                      onSelected: (selected) => setStateDialog(() => isAddingDebt = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('دفعة قبض')),
                      selected: !isAddingDebt,
                      onSelected: (selected) => setStateDialog(() => isAddingDebt = false),
                    ),
                  ),
                ],
              ),
