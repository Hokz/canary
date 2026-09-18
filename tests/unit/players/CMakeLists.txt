target_sources(
    canary_ut
    PRIVATE combat_tactics_test.cpp
            player_item_batch_test.cpp
            reward_iteration_test.cpp
)

add_subdirectory(components)
add_subdirectory(condition)
add_subdirectory(imbuements)
add_subdirectory(wheel)

target_sources(
    canary_ut
    PRIVATE forge_test.cpp party_test.cpp
)
